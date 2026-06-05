import requests
import time
import math
import sys

# --- CONSTANTS ---
BASE_URL = "http://localhost:8014"
ALTITUDE = 5           # Takeoff altitude (meters)
DRONE_SPEED = 2       # Air speed (m/s)
ACCURACY = 2.0         # Waypoint arrival threshold (meters)
LOOP_FREQUENCY = 2.0   # Hz

# NED waypoints: (north, east, down) — all within 50m of home
# down negative = up, so -ALTITUDE maintains flight altitude
WAYPOINTS = [
    (15, 10, -ALTITUDE),
    (-5, 30, -ALTITUDE),
    (-15, 20, -ALTITUDE),
    (25, 20, -ALTITUDE),
]

HEADINGS = [
    135,
    225,
    0,
    95
]

# --- STATE ---
current_waypoint = 0
is_going = False


def euclidean_distance(p1, p2):
    return math.sqrt((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2 + (p1[2]-p2[2])**2)


def setup():
    """Arm, takeoff, and set air speed for the leader drone."""
    print("--- SETUP START ---")

    # 1. Arm
    print("Arming vehicle...")
    arm_result = requests.get(f"{BASE_URL}/command/arm")
    if arm_result.status_code != 200:
        print(f"ERROR: Failed to arm. Code: {arm_result.status_code}")
        sys.exit(1)

    # 2. Takeoff
    print(f"Taking off to {ALTITUDE}m...")
    takeoff_result = requests.get(f"{BASE_URL}/command/takeoff", params={"alt": ALTITUDE})
    if takeoff_result.status_code != 200:
        print(f"ERROR: Takeoff failed. Code: {takeoff_result.status_code}")
        sys.exit(1)

    # 3. Set air speed
    print(f"Setting air speed to {DRONE_SPEED} m/s...")
    speed_result = requests.get(f"{BASE_URL}/command/set_air_speed", params={"new_v": DRONE_SPEED})
    if speed_result.status_code != 200:
        print(f"ERROR: Failed to set air speed. Code: {speed_result.status_code}")
        sys.exit(1)

    print("--- SETUP COMPLETE ---")


def loop():
    """Navigate through waypoints, performing yaw rotation at each one.
    Returns True to continue, False when mission is complete."""
    global current_waypoint, is_going

    try:
        # 1. Get current NED position
        pos_result = requests.get(f"{BASE_URL}/telemetry/ned")
        if pos_result.status_code != 200:
            print(f"ERROR: Could not read NED position. Code: {pos_result.status_code}")
            return True
        pos_data = pos_result.json()["info"]["position"]
        current_pos = (pos_data["x"], pos_data["y"], pos_data["z"])

        waypoint = WAYPOINTS[current_waypoint]

        # 2. If not navigating, send go_to_ned for the current waypoint
        if not is_going:
            data = {"x": waypoint[0], "y": waypoint[1], "z": waypoint[2], "look_at_target": True}
            result = requests.post(f"{BASE_URL}/movement/go_to_ned", json=data)
            if result.status_code != 200:
                print(f"ERROR: go_to_ned failed. Code: {result.status_code}")
                return True
            print(f"Navigating to waypoint {current_waypoint}: {waypoint}")
            is_going = True

        # 3. Check distance to waypoint
        dist = euclidean_distance(current_pos, waypoint)
        print(f"  pos=({current_pos[0]:.1f}, {current_pos[1]:.1f}, {current_pos[2]:.1f})  "
              f"dist={dist:.1f}m to WP{current_waypoint}")

        if dist <= ACCURACY:
            print(f"Arrived at waypoint {current_waypoint}. Performing yaw rotation...")

            # 4. Yaw rotation
            next_heading = HEADINGS[current_waypoint]
            time.sleep(5)
            requests.get(f"{BASE_URL}/movement/set_heading", params={"heading": next_heading})
            time.sleep(5)
            print(f"Yaw rotation complete at waypoint {current_waypoint}.")

            # 5. Advance to next waypoint
            current_waypoint += 1
            is_going = False
            if current_waypoint >= len(WAYPOINTS):
                return False

        return True

    except Exception as e:
        print(f"Error in loop: {e}")
        return True


# --- MAIN ---
if __name__ == "__main__":
    try:
        setup()
        while True:
            if not loop():
                print("Mission complete.")
                break
            time.sleep(1 / LOOP_FREQUENCY)
    except KeyboardInterrupt:
        print("\n--- INTERRUPT DETECTED ---")
        print("Initiating RTL...")
        requests.get(f"{BASE_URL}/command/rtl")
        print("Program terminated.")
        sys.exit(0)
