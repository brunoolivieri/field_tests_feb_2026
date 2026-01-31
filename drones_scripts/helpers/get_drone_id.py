import socket

def get_drone_id():
    hostname = socket.gethostname()
    drone_id = int(hostname[5:])
    return drone_id