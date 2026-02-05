import requests
import math

from tracker.mission_tracker import run_mission_tracker
from utils.get_drone_id import get_drone_id
# In this mission, the drone will make a square by turning right every SQUARE_SIDE meters.
# The drone will maintain a constant altitude of 10 meters.
# The drone will have a maximum speed of DRONE_SPEED meters per second.
# The drone will considered that it arrived at the waypoint when
# the distance to the waypoint is less than ACCURACY meters.

SQUARE_SIDE = 10
ACCURACY = 1.0
BASE_URL = f"http://localhost:{8000 + get_drone_id()}"
LOOP_FREQUENCY = 2.0  # Hz
DRONE_SPEED = 5.0 # m/s

# State
current_waypoint = 0
is_going = False
target = [None, None, None]

def euclidean_distance(point1, point2):
    return math.sqrt((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2 + (point1[2] - point2[2])**2)

def square_mission_setup():
    global current_waypoint, is_going, waypoints
    current_waypoint = 0
    is_going = False
    waypoints = [
        (SQUARE_SIDE, 0, 0), 
        (0, SQUARE_SIDE, 0),
        (-SQUARE_SIDE, 0, 0),
        (0, -SQUARE_SIDE, 0)
    ]

    speed_success = requests.get(f"{BASE_URL}/command/set_air_speed", params={"new_v": DRONE_SPEED})
    if speed_success.status_code == 200:
        print(f"Air speed set to {DRONE_SPEED} m/s")
    else:
        print("Failed to set air speed.")
        return False
    
    return True

def square_mission_step(current_position):
    global current_waypoint, is_going, waypoints

    if not is_going:
        target[0] = current_position[0] + waypoints[current_waypoint][0]
        target[1] = current_position[1] + waypoints[current_waypoint][1]
        target[2] = current_position[2] + waypoints[current_waypoint][2]

        data = {
            "x": waypoints[current_waypoint][0],
            "y": waypoints[current_waypoint][1],
            "z": -waypoints[current_waypoint][2]
        }
        command_response = requests.post(f"{BASE_URL}/movement/drive", json=data)
        if command_response.status_code == 200:
            print(f"Going to waypoint {current_waypoint}: ({target[0]}, {target[1]}, {-target[2]})")
        else:
            print("Failed to send go_to_position command.")
            return False
        is_going = True

    if target[0] is None:
        return True
    
    target_dist = euclidean_distance(current_position, (target[0], target[1], target[2]))
    
    if target_dist <= ACCURACY:
        current_waypoint += 1
        is_going = False
        if current_waypoint >= len(waypoints):
            return False

    return True

run_mission_tracker(BASE_URL, LOOP_FREQUENCY, square_mission_setup, square_mission_step)
