import pandas as pd
import networkx as nx
import sys
import os
from openpyxl import load_workbook
from openpyxl.utils.exceptions import InvalidFileException

def allocate_seats(excel_path):
    if not os.path.exists(excel_path):
        print(f"❌ File not found: {excel_path}")
        return

    # Load sheets
    adj_df = pd.read_excel(excel_path, sheet_name='Adjacency')
    teams_df = pd.read_excel(excel_path, sheet_name='Teams')
    try:
        fixed_df = pd.read_excel(excel_path, sheet_name='Fixed', dtype=str)
    except Exception:
        fixed_df = pd.DataFrame(columns=['Seat No', 'Subteam', 'Technology'])

    # Step 1: Build graph
    G = nx.Graph()
    teams_sorted = teams_df.sort_values(by="Count", ascending=False)
    for _, row in teams_sorted.iterrows():
        seat = str(row['Seat No']).strip()
        for adj in row[1:]:
            if pd.notna(adj):
                G.add_edge(seat, str(adj).strip())

    # Step 2: Get clusters
    clusters = sorted(list(nx.connected_components(G)), key=len, reverse=True)

    # Step 3: Handle fixed seats
    assigned = {}
    used_seats = set()

    for _, row in fixed_df.iterrows():
        seat = str(row['Seat No']).strip()
        subteam = row['Subteam']
        tech = row['Technology']
        assigned[seat] = (subteam, tech)
        used_seats.add(seat)

    # Step 4: Assign team-tech blocks to clusters
    for _, row in teams_df.iterrows():
        subteam = row['Subteam']
        tech = row['Technology']
        count = int(row['Count'])

        placed = False
        for cluster in clusters:
            free = [s for s in cluster if s not in used_seats]
            if len(free) >= count:
                for seat in free[:count]:
                    assigned[seat] = (subteam, tech)
                    used_seats.add(seat)
                placed = True
                break
        if not placed:
            # Fallback to any available unassigned seats
            free_anywhere = [s for s in G.nodes if s not in used_seats]
            if len(free_anywhere) >= count:
                for seat in free_anywhere[:count]:
                    assigned[seat] = (subteam, tech)
                    used_seats.add(seat)
                print(f"⚠️ Assigned {count} disjointed seats for {subteam} ({tech}) (no adjacent group found)")
            else:
                print(f"❌ Not enough seats available for {subteam} ({tech}) — need {count}, found {len(free_anywhere)}")

    # Step 5: Output results
    output = []
    for seat in sorted(G.nodes, key=lambda x: int(x)):
        if seat in assigned:
            subteam, tech = assigned[seat]
        else:
            subteam, tech = "Unassigned", ""
        output.append((seat, subteam, tech))

    output_df = pd.DataFrame(output, columns=["Seat No", "Subteam", "Technology"])
    output_df["Seat No"] = output_df["Seat No"].astype(int)
    output_df = output_df.sort_values(by="Seat No")

    out_path = os.path.splitext(excel_path)[0] + "-allocation-output.xlsx"

    sheet_name = "Allocation"
    out_path = os.path.splitext(excel_path)[0] + "-allocation-output.xlsx"

    try:
        book = load_workbook(out_path)
        if sheet_name in book.sheetnames:
            del book[sheet_name]
        with pd.ExcelWriter(out_path, engine='openpyxl', mode='a', if_sheet_exists='replace') as writer:
            writer.book = book
            output_df.to_excel(writer, sheet_name=sheet_name, index=False)
    except FileNotFoundError:
        # File doesn't exist yet — create fresh
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
