from uav_api.run_api import run_with_args
from helpers.get_drone_id import get_drone_id

def init_api():
    drone_id = get_drone_id()
    raw_args = [
        "--uav_connection", f"127.0.0.1:{10000 + drone_id}",
        "--sysid", f"{drone_id}",
        "--port", f"{8000 + drone_id}",
    ]

    api_process = run_with_args(raw_args)

    return api_process