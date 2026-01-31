import requests
import time

from helpers.position_tracker import PositionTracker
from helpers.diagnostics import get_diagnostics

def run_mission_tracker(base_url: str, loop_frequency: float, mission_setup: callable, mission_step: callable):
    # Arming
    arm_response = requests.get(f"{base_url}/command/arm")
    if arm_response.status_code == 200:
        print("Arming successful.")
    else:
        print("Failed to arm.")
        exit(1)

    # Takeoff
    takeoff_response = requests.get(f"{base_url}/command/takeoff?alt=10")
    if takeoff_response.status_code == 200:
        print("Takeoff successful.")
    else:
        print("Failed to takeoff.")
        exit(1)

    # Setting up Position Tracker
    position_tracker = PositionTracker()

    # Diagnostics
    print("")
    get_diagnostics(base_url)
    print("")

    # Mission Loop
    setup_success = mission_setup()
    if not setup_success:
        print("Mission setup failed.")
        exit(1)

    simulation_time = 0.1
    last_tick = time.time()
    while True:
        # Get current 
        if time.time() - last_tick < 1/loop_frequency:
            continue
        
        simulation_time += 1/loop_frequency
        last_tick = time.time()
        
        position_response = requests.get(f"{base_url}/telemetry/ned")
        if position_response.status_code != 200:
            print("Failed to get position.")
            break
        position_data = position_response.json()["info"]["position"]
        current_position = (position_data['x'], position_data['y'], -position_data['z'])
        
        # Track position
        print("Tracking position at {:.2f}s: {}".format(simulation_time, current_position))
        position_tracker.track_position(simulation_time, current_position)
        
        # Mission logic
        if not mission_step(current_position):
            print("Mission step indicated to stop the mission.")
            position_tracker.save_to_csv("mission_position_log.csv")
            break

    # Mission complete, landing
    land_response = requests.get(f"{base_url}/command/land")
    if land_response.status_code == 200:
        print("Landing successful.")
    else:
        print("Failed to land.")