import pandas as pd
import python_logging_framework as plog
import networkx as nx
import sys
import os
from collections import namedtuple

# Constants
SEAT_NO_COL = "Seat No"
ADJACENCY_SHEET = "Adjacency"
TEAMS_SHEET = "Teams"
FIXED_SHEET = "Fixed"
AssignedDetails = namedtuple("AssignedDetails", ["subteam", "technology"])


def allocate_seats(excel_path):
    """
    Main function to allocate seats based on adjacency, team requirements, and fixed assignments.
    Generates a new Excel file with the final allocation.

    Args:
        excel_path (str): Path to the input Excel file containing the required sheets.
    """
    if not os.path.exists(excel_path):
        plog.log_error(f"❌ File not found: {excel_path}")
        return

    adj_df, teams_df, fixed_df = load_input_data(excel_path)
    graph = build_seat_graph(adj_df)
    assigned, used_seats = assign_fixed_seats(graph, fixed_df)
    clusters = get_seat_clusters(graph)
    assign_teams_to_clusters(graph, teams_df, assigned, used_seats, clusters)
    export_seat_allocation(excel_path, graph, assigned)


def load_input_data(excel_path):
    """
    Loads the input sheets from the Excel file.

    Returns:
        tuple: DataFrames for adjacency, teams, and fixed seat assignments.
    """
    required_columns = {
        "Adjacency": [SEAT_NO_COL],
        "Teams": ["Subteam", "Technology", "Count"],
        "Fixed": [SEAT_NO_COL, "Subteam", "Technology"],
    }
    adj_df = pd.read_excel(excel_path, sheet_name=ADJACENCY_SHEET)
    teams_df = pd.read_excel(excel_path, sheet_name=TEAMS_SHEET)
    fixed_df = pd.read_excel(excel_path, sheet_name=FIXED_SHEET, dtype=str)
    for name, df in zip(["Adjacency", "Teams", "Fixed"], [adj_df, teams_df, fixed_df]):
        missing = [col for col in required_columns[name] if col not in df.columns]
        if missing:
            raise ValueError(f"❌ Missing required columns in {name} sheet: {', '.join(missing)}")
    return adj_df, teams_df, fixed_df


def build_seat_graph(adj_df):
    """
    Constructs a bidirectional graph of seat adjacencies.

    Args:
        adj_df (DataFrame): Adjacency data.

    Returns:
        networkx.Graph: Graph of seat connections.
    """
    G = nx.Graph()
    for _, row in adj_df.iterrows():
        seat = parse_seat(row[SEAT_NO_COL])
        if seat:
            for adj in row[1:]:
                adj_seat = parse_seat(adj)
                if adj_seat:
                    G.add_edge(seat, adj_seat)
    return G


def parse_seat(value):
    """
    Safely parses a seat number to a string, ensuring it's a valid integer representation.

    Args:
        value: Input seat value.

    Returns:
        str or None: Parsed seat number or None if invalid.
    """
    if pd.isna(value) or not str(value).strip():
        return None
    try:
        return str(int(value)).strip()
    except (ValueError, TypeError):
        plog.log_warning(f"⚠️ Warning: Could not parse seat value '{value}'. Skipping.")
        return None


def assign_fixed_seats(graph, fixed_df):
    """
    Assigns fixed seats and ensures they are included in the graph.

    Args:
        graph (Graph): Seat graph.
        fixed_df (DataFrame): Fixed seat assignments.

    Returns:
        tuple: Assigned dict and set of used seats.
    """
    assigned = {}
    used_seats = set()
    for _, row in fixed_df.iterrows():
        seat = parse_seat(row[SEAT_NO_COL])
        subteam = row["Subteam"]
        tech = row["Technology"]
        if seat:
            assigned[seat] = AssignedDetails(subteam, tech)
            used_seats.add(seat)
            if seat not in graph:
                graph.add_node(seat)
    return assigned, used_seats


def get_seat_clusters(graph):
    """
    Finds clusters of connected seats in the graph.

    Args:
        graph (Graph): Seat graph.

    Returns:
        list: Sorted list of connected components.
    """
    return sorted(nx.connected_components(graph), key=len, reverse=True)


def assign_teams_to_clusters(graph, teams_df, assigned, used_seats, clusters):
    """
    Assigns teams to clusters, trying to maximize adjacency and group integrity.

    Args:
        graph (Graph): Seat graph.
        teams_df (DataFrame): Team count and metadata.
        assigned (dict): Current seat assignments.
        used_seats (set): Used seat IDs.
        clusters (list): List of seat clusters.
    """
    teams_sorted = teams_df.sort_values(by="Count", ascending=False)
    for _, row in teams_sorted.iterrows():
        subteam, tech, count = row["Subteam"], row["Technology"], int(row["Count"])
        if not try_assign_to_best_cluster(clusters, assigned, subteam, tech, count):
            assign_disjointed(graph, assigned, subteam, tech, count)


def try_assign_to_best_cluster(clusters, assigned, subteam, tech, count):
    """
    Attempts to place a team into the best-fit cluster based on score.

    Returns:
        bool: True if assignment successful, else False.
    """
    best_cluster, best_score, best_min_seat = None, -1, float("inf")
    for cluster in clusters:
        free = [s for s in cluster if s not in assigned]
        if len(free) < count:
            continue
        score = compute_score(cluster, assigned, subteam, tech)
        # Tie-breaker: prefer the cluster with the lowest seat number for deterministic output
        min_seat = min(map(int, free)) if free else float("inf")
        if score > best_score or (score == best_score and min_seat < best_min_seat):
            best_score, best_min_seat, best_cluster = score, min_seat, cluster
    if best_cluster:
        assign_seats(
            sorted((s for s in best_cluster if s not in assigned), key=int),
            assigned,
            subteam,
            tech,
            count,
        )
        return True
    return False


def compute_score(cluster, assigned, subteam, tech):
    """
    Computes weighted score based on matching subteams and technology.

    Returns:
        int: Score.
    """
    subteam_matches = sum(1 for s in cluster if s in assigned and assigned[s][0] == subteam)
    tech_matches = sum(1 for s in cluster if s in assigned and assigned[s][1] == tech)
    return subteam_matches * 10 + tech_matches


def assign_seats(seats, assigned, subteam, tech, count):
    """
    Assigns a fixed number of seats.

    Args:
        seats (list): List of seat IDs.
    """
    for seat in seats[:count]:
        assigned[seat] = AssignedDetails(subteam, tech)


def assign_disjointed(graph, assigned, subteam, tech, count):
    """
    Fallback seat assignment for disjointed, non-adjacent seating.
    """
    free = sorted((s for s in graph.nodes if s not in assigned and s.isdigit()), key=int)
    if len(free) >= count:
        assign_seats(free, assigned, subteam, tech, count)
        plog.log_warning(f"⚠️ Assigned {count} disjointed seats for {subteam} ({tech})")
    else:
        plog.log_error(
            f"❌ Not enough seats available for {subteam} ({tech}) — need {count}, found {len(free)}"
        )


def export_seat_allocation(excel_path, graph, assigned):
    """
    Writes the final seat allocation to a new Excel file.
    """
    output = [
        (int(seat), *assigned.get(seat, ("Unassigned", "")))
        for seat in graph.nodes
        if seat.isdigit()
    ]
    df = pd.DataFrame(output, columns=[SEAT_NO_COL, "Subteam", "Technology"]).sort_values(
        by="Seat No"
    )
    out_path = os.path.splitext(excel_path)[0] + "-allocation-output.xlsx"
    try:
        if os.path.exists(out_path):
            os.remove(out_path)
        df.to_excel(out_path, sheet_name="Allocation", index=False)
        plog.log_info(f"✅ Seat allocation written to sheet 'Allocation' in {out_path}")
    except Exception as e:
        plog.log_error(f"❌ Error writing Excel file: {out_path} ({e})")


# Entry point
if __name__ == "__main__":
    plog.initialise_logger(log_file_path="auto", level="INFO")

    if len(sys.argv) < 2:
        plog.log_info("Usage: python allocate_seats.py <input_excel_file>")
    else:
        allocate_seats(sys.argv[1])
