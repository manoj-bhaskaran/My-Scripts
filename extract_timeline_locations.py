import json

# 🔧 Switch: Set to True to print only first 100 records
LIMIT_OUTPUT = True
MAX_RECORDS = 100

def main():
    input_file = r"G:\My Drive\Google Maps Timeline\timeline.json"

    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for segment in data.get("semanticSegments", []):
        for point_entry in segment.get("timelinePath", []):
            time = point_entry.get("time")
            point = point_entry.get("point")
            print(f"time: {time}, point: {point}")

            count += 1
            if LIMIT_OUTPUT and count >= MAX_RECORDS:
                print(f"\n🔔 Stopped after {MAX_RECORDS} records (LIMIT_OUTPUT = True)")
                return

if __name__ == "__main__":
    main()
