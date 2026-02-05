from uav_api.run_api import run_with_args
from get_drone_id import get_drone_id

def init_api():
    drone_id = get_drone_id()
    print(drone_id)
    raw_args = [
        "--uav_connection", f"127.0.0.1:{10000+drone_id}",
        "--sysid", f"{drone_id}",
        "--port", f"{8000+drone_id}",
        "--gradys_gs", "10.0.2.236:8000",
        "--log_console", "GRADYS_GS", "API",
        "--python_path", "~/.env/bin/python3",
        "--scripts_path", "~/python_scripts",
    ]

    api_process = run_with_args(raw_args)

    return api_process
