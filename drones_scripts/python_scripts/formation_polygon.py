from pathlib import Path

import requests
import time
import math
import sys
import argparse

def get_drone_id():
    script_dir = str(Path(__file__).parent.resolve()).split("_")[-1]
    print(script_dir)
    return int(script_dir)

def offset_id(drone_id):
    drone_relation = {
        10: 1,
        11: 2,
        12: 3,
        13: 4,
        14: 5
    }

    return drone_relation[drone_id]

# --- GLOBALS ---
DRONE_ID = get_drone_id()
N = 4
RADIUS = 10
ORIENTATION = "horizontal"
VERTICAL_AXIS = "north"
ALTITUDE_ABS = 0
ALTITUDE_VOO = 5
OFFSET_ALT = 2
DRONE_URL = f"http://localhost:{8000 + DRONE_ID}"
MASTER_URL = "http://localhost:8014"

def compute_offset(heading_deg):
    """Compute the formation offset (north, east, alt) in meters for this drone's vertex."""
    theta = (2 * math.pi * (offset_id(DRONE_ID) - 1) / N) + math.radians(heading_deg) + math.pi/4

    if ORIENTATION == "horizontal":
        offset_north = RADIUS * math.cos(theta)
        offset_east = RADIUS * math.sin(theta)
        offset_alt = 0
    elif VERTICAL_AXIS == "north":
        offset_north = RADIUS * math.cos(theta)
        offset_east = 0
        offset_alt = RADIUS * math.sin(theta)
    else:  # vertical, east
        offset_north = 0
        offset_east = RADIUS * math.cos(theta)
        offset_alt = RADIUS * math.sin(theta)

    return offset_north, offset_east, offset_alt


def setup():
    """Arm and takeoff the follower drone."""
    global ALTITUDE_ABS

    print("--- SETUP START ---")

    # 1. Capture absolute altitude
    print("Capturing absolute altitude...")
    pos_result = requests.get(f"{DRONE_URL}/telemetry/gps")
    if pos_result.status_code == 200:
        data = pos_result.json()
        ALTITUDE_ABS = float(data['info']['position']['alt'])
    print(f"Absolute altitude: {ALTITUDE_ABS}m")

    # 2. Arm
    print("Arming vehicle...")
    arm_result = requests.get(f"{DRONE_URL}/command/arm")
    if arm_result.status_code != 200:
        print(f"ERROR: Failed to arm. Code: {arm_result.status_code}")
        sys.exit(1)

    # 3. Takeoff
    print(f"Taking off to {ALTITUDE_VOO}m...")
    takeoff_result = requests.get(f"{DRONE_URL}/command/takeoff", params={"alt": ALTITUDE_VOO})
    if takeoff_result.status_code != 200:
        print(f"ERROR: Takeoff failed. Code: {takeoff_result.status_code}")
        sys.exit(1)

    print("--- SETUP COMPLETE ---")


def loop():
    global ALTITUDE_ABS
    """Poll master position, compute formation offset, send non-blocking go_to_gps."""
    try:
        # 1. Get master GPS position
        pos_result = requests.get(f"{MASTER_URL}/telemetry/gps")
        if pos_result.status_code != 200:
            print(f"ERROR: Could not read master position. Code: {pos_result.status_code}")
            return

        data = pos_result.json()
        master_pos = data['info']['position']
        master_lat = float(master_pos['lat'])
        master_lon = float(master_pos['lon'])
        master_alt = float(master_pos['alt'])

        general_result = requests.get(f"{MASTER_URL}/telemetry/general")
        if general_result.status_code != 200:
            print(f"ERROR: Could not read master heading. Code: {general_result.status_code}")
            return

        heading_deg = float(general_result.json()['info']['heading'])

        # 2. Compute formation offset
        offset_north, offset_east, offset_alt = compute_offset(heading_deg)

        # 3. Convert meter offsets to GPS deltas
        delta_lat = offset_north / 111111.0
        delta_lon = offset_east / (111111.0 * math.cos(math.radians(master_lat)))

        target_lat = master_lat + delta_lat
        target_lon = master_lon + delta_lon

        raw_target_alt = (master_alt - ALTITUDE_ABS) + offset_alt
        target_alt = max(2.0, raw_target_alt)

        # 4. Send non-blocking movement command
        fly_data = {
            "lat": target_lat,
            "long": target_lon,
            "alt": target_alt,
        }
        result = requests.post(f"{DRONE_URL}/movement/go_to_gps", json=fly_data)
        if result.status_code != 200:
            print(f"ERROR: Movement failed. Code: {result.status_code}")
            print(f"Detail: {result.text}")
            return

        print(f"[drone_id={DRONE_ID}] Moving to: {target_lat:.6f}, {target_lon:.6f}, alt={target_alt:.1f}m")

    except Exception as e:
        print(f"Error in loop: {e}")


# --- MAIN ---
if __name__ == "__main__":
    try:
        setup()
        while True:
            loop()
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n--- INTERRUPT DETECTED ---")
        print("Initiating RTL (Return to Launch)...")
        requests.get(f"{DRONE_URL}/command/rtl")
        print("Program terminated.")
        sys.exit(0)
