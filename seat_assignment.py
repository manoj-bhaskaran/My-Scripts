import pandas as pd
import networkx as nx
import sys
import os

def allocate_seats(excel_path):
    from openpyxl.utils.exceptions import InvalidFileException

    if not os.path.exists(excel_path):
        print(f"❌ File not found: {excel_path}")
        return

    # Load input sheets
    adj_df = pd.read_excel(excel_path, sheet_name='Adjacency')
    teams_df = pd.read_excel(excel_path, sheet_name='Teams')
    try:
        fixed_df = pd.read_excel(excel_path, sheet_name='Fixed', dtype=str)
    except Exception:
        fixed_df = pd.DataFrame(columns=['Seat No', 'Subteam', 'Technology'])

    # Step 1: Build bidirectional seat adjacency graph
    G = nx.Graph()
    for _, row in adj_df.iterrows():
        try:
            seat = str(int(float(row['Seat No']))).strip()
        except:
            continue
        for adj in row[1:]:
            if pd.notna(adj):
                try:
                    adj_seat = str(int(float(adj))).strip()
                    G.add_edge(seat, adj_seat)
                    G.add_edge(adj_seat, seat)
                except:
                    continue

    # Step 2: Find connected seat clusters
    clusters = sorted(list(nx.connected_components(G)), key=len, reverse=True)

    # Step 3: Assign fixed seats
    assigned = {}
    used_seats = set()
    for _, row in fixed_df.iterrows():
        seat = str(int(float(row['Seat No']))).strip()
        subteam = row['Subteam']
        tech = row['Technology']
        assigned[seat] = (subteam, tech)
        used_seats.add(seat)

    # Ensure fixed seats exist in graph
    for seat in assigned:
        if seat not in G:
            G.add_node(seat)

    # Step 4: Assign teams to clusters (largest teams first), with weighted scoring and tie-breaking
    teams_sorted = teams_df.sort_values(by="Count", ascending=False)
    for _, row in teams_sorted.iterrows():
        subteam = row['Subteam']
        tech = row['Technology']
        count = int(row['Count'])
        placed = False

        best_cluster = None
        best_score = -1
        best_min_seat = float('inf')

        for cluster in clusters:
            free = [s for s in cluster if s not in assigned]
            if len(free) < count:
                continue

            subteam_matches = sum(1 for s in cluster if s in assigned and assigned[s][0] == subteam)
            tech_matches = sum(1 for s in cluster if s in assigned and assigned[s][1] == tech)
            score = (subteam_matches * 10) + tech_matches
            min_free_seat = min([int(s) for s in free]) if free else float('inf')

            if score > best_score or (score == best_score and min_free_seat < best_min_seat):
                best_score = score
                best_min_seat = min_free_seat
                best_cluster = cluster

        if best_cluster:
            free_seats = sorted([s for s in best_cluster if s not in assigned], key=lambda x: int(x))
            assigned_count = 0
            for seat in free_seats:
                assigned[seat] = (subteam, tech)
                used_seats.add(seat)
                assigned_count += 1
                if assigned_count >= count:
                    break
            placed = True

        if not placed:
            # Try disjointed seats
            free_anywhere = [s for s in G.nodes if s not in assigned]
            if len(free_anywhere) >= count:
                fallback_assigned = 0
                for seat in sorted(free_anywhere, key=lambda x: int(x)):
                    if seat not in assigned:
                        assigned[seat] = (subteam, tech)
                        used_seats.add(seat)
                        fallback_assigned += 1
                        if fallback_assigned >= count:
                            break
                print(f"⚠️ Assigned {count} disjointed seats for {subteam} ({tech})")
            else:
                print(f"❌ Not enough seats available for {subteam} ({tech}) — need {count}, found {len(free_anywhere)}")

    # Step 5: Create final output, sorted by seat number
    output = []
    for seat in G.nodes:
        if seat in assigned:
            subteam, tech = assigned[seat]
        else:
            subteam, tech = "Unassigned", ""
        output.append((int(float(seat)), subteam, tech))

    output_df = pd.DataFrame(output, columns=["Seat No", "Subteam", "Technology"])
    output_df = output_df.sort_values(by="Seat No")

    # Step 6: Export to Excel (overwrite file if exists)
    sheet_name = "Allocation"
    out_path = os.path.splitext(excel_path)[0] + "-allocation-output.xlsx"

    try:
        if os.path.exists(out_path):
            os.remove(out_path)
        output_df.to_excel(out_path, sheet_name=sheet_name, index=False)
    except InvalidFileException:
        print(f"❌ Invalid Excel file: {out_path}")
        return

    print(f"✅ Seat allocation written to sheet '{sheet_name}' in {out_path}")

# Entry point
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python allocate_seats.py <input_excel_file>")
    else:
        allocate_seats(sys.argv[1])
