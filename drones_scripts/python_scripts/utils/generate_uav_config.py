import configparser

from get_drone_id import get_drone_id
from pathlib import Path


def main():
    config = configparser.ConfigParser()
    sysid = get_drone_id()

    config["api"] = {
        "port": str(8000 + sysid),
        "uav_connection": "127.0.0.1:17171",
        "connection_type": "udpin",
        "sysid": sysid,
        "gradys_gs": "127.0.0.1:8000",
        "scripts_path": "/home/pi/field_tests_feb_2026/drones_scripts/python_scripts"
    }

    output_path = Path("/etc/uavs/default.ini")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        config.write(f)

    print(f"Generated {output_path}")


if __name__ == "__main__":
    main()
