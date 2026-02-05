import requests
import math

from ..tracker.mission_tracker import run_mission_tracker
from ..utils.get_drone_id import get_drone_id

# In this mission, the drone will fly back and forth between two points
# along the x-axis.
# The points will be WAYPOINT_DIST meters apart, and the drone will
# visit N_WAYPOINT waypoints in total.
# The drone will maintain a constant altitude of 10 meters.
# The drone will have a maximum speed of DRONE_SPEED meters per second.
# The drone will considered that it arrived at the waypoint when
# the distance to the waypoint is less than ACCURACY meters.

N_WAYPOINT = 10
WAYPOINT_DIST = 20
ACCURACY = 1.0
BASE_URL = f"http://localhost:{8000 + get_drone_id()}"
LOOP_FREQUENCY = 2.0  # Hz
DRONE_SPEED = 5.0 # m/s

# State
current_waypoint = 1
is_going = False
target = [None, None, None]

def euclidean_distance(point1, point2):
    return math.sqrt((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2 + (point1[2] - point2[2])**2)

def straight_mission_setup():
    global current_waypoint, is_going
    current_waypoint = 1
    is_going = False

    speed_success = requests.get(f"{BASE_URL}/command/set_air_speed", params={"new_v": DRONE_SPEED})
    if speed_success.status_code == 200:
        print(f"Air speed set to {DRONE_SPEED} m/s")
    else:
        print("Failed to set air speed.")
        return False
    
    return True

def straight_mission_step(current_position):
    global current_waypoint, is_going, target


    if not is_going:
        waypoint_y = (1 if current_waypoint%2==1 else -1) * WAYPOINT_DIST
        waypoint_x = 0
        waypoint_z = 0  # Maintain constant altitude of 10 meters

        target[0] = current_position[0] + waypoint_x
        target[1] = current_position[1] + waypoint_y
        target[2] = current_position[2] + waypoint_z

        data = {
            "x": waypoint_x,
            "y": waypoint_y,
            "z": -waypoint_z
        }
        command_response = requests.post(f"{BASE_URL}/movement/drive", json=data)
        if command_response.status_code == 200:
            print(f"Going to waypoint {current_waypoint}: ({target[0]}, {target[1]}, {target[2]})")
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
        if current_waypoint > N_WAYPOINT:
            return False
        

    return True

run_mission_tracker(BASE_URL, LOOP_FREQUENCY, straight_mission_setup, straight_mission_step)
