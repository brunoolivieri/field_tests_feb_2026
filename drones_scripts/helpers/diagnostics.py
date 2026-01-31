import requests

# This function should only be called once the drone is armed.
def get_diagnostics(url):

    battery = "N/A"
    satellites = "N/A"
    home_info = {
        "lat": "N/A",
        "lon": "N/A",
        "altitude": "N/A",
        "x": "N/A",
        "y": "N/A",
        "z": "N/A"
    }

    try:
        battery_res = requests.get(f"{url}/telemetry/battery_info") 
        if battery_res.status_code == 200:
            battery_info = battery_res.json()
            battery = battery_info["info"]["battery_remaining"]
        else:
            raise Exception("Failed to get battery info")
        
        gps_raw_res = requests.get(f"{url}/telemetry/gps_raw")
        if gps_raw_res.status_code == 200:
            gps_raw_res_info = gps_raw_res.json()
            satellites = gps_raw_res_info["info"]["satelites"]
        else:
            raise Exception("Failed to get satellites info")
        
        home_res = requests.get(f"{url}/telemetry/home_info")
        if home_res.status_code == 200:
            home_info = home_res.json()
        else:
            raise Exception("Failed to get home info")
    except Exception as e:
        print(f"Unable to generate diagnostics report properly. Error: {e}")

    print("----- DIAGNOSTICS REPORT -----")
    print(f"Battery Remaining: {battery}%")
    print(f"Visible Satellites: {satellites}")
    print(f"Home Location: Lat: {home_info['lat']}, Lon: {home_info['lon']}, Alt: {home_info['altitude']}, x: {home_info['x']}, y: {home_info['y']}, z: {home_info['z']}")
    print("------------------------------")
