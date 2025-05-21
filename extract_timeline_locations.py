import json

def main():
    input_file = r"G:\My Drive\Google Maps Timeline\timeline.json"

    # Load JSON file
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Loop through semanticSegments → timelinePath
    for segment in data.get("semanticSegments", []):
        for point_entry in segment.get("timelinePath", []):
            time = point_entry.get("time")
            point = point_entry.get("point")
            print(f"time: {time}, point: {point}")

if __name__ == "__main__":
    main()
