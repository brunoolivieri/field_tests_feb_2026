import requests
import time
import math
import sys

from tracker.mission_tracker import run_mission_tracker

# --- CONFIGURAÇÕES ---
FOLLOWER_URL = "http://localhost:8004" # Drone que vai seguir
LEADER_URL   = "http://10.0.2.159:8003" # Drone a ser seguido

# Offset em metros (Para o drone seguidor não bater no líder)
OFFSET_NORTH = -3  # 3 metros atrás (se o líder estiver indo para o Norte)
OFFSET_EAST  = 0   # Alinhado horizontalmente
OFFSET_ALT   = 2.0
ALTITUDE_VOO = 2  # Altura de cruzeiro

ALTITUDE_ABS = 0  # Variável global
LEADER_HOME_ALT = 0  # Variável global

def setup():
    """
    Função chamada uma única vez no início.
    Responsável por armar e decolar o drone seguidor.
    """
    print("--- INICIANDO SETUP ---")

    global ALTITUDE_ABS, LEADER_HOME_ALT

    # 1. Captura altitute absoluta
    print("Capturando altitude absoluta...")
    pos_result = requests.get(f"{FOLLOWER_URL}/telemetry/gps")

    if pos_result.status_code != 200:
        print(f"ERRO: Não foi possível capturar a altitude absoluta. Code: {pos_result.status_code}")
        sys.exit(1)

    data = pos_result.json()
    l_pos = data['info']['position']
    ALTITUDE_ABS = float(l_pos['alt'])

    print(f"Altitude absoluta capturada: {ALTITUDE_ABS}m")

    # 2. Captura da altitude inicial do lider
    print("Capturando altitude inicial do líder...")
    home_result = requests.get(f"{LEADER_URL}/telemetry/home_info")
    if home_result.status_code != 200:
        print(f"ERRO: Não foi possível capturar a altitude inicial do líder. Code: {home_result.status_code}")
        sys.exit(1)

    data = home_result.json()
    LEADER_HOME_ALT = float(data['altitude'])

    print(f"Altitude inicial do líder capturada: {LEADER_HOME_ALT}m")

    print("--- SETUP CONCLUÍDO ---")

    return True

def loop(current_position):
    """
    Função rodada repetidamente.
    Lê a posição do Líder, calcula o Offset e move o Seguidor.
    """
    try:
        # 1. PEGAR POSIÇÃO DO LÍDER (Pulling)
        pos_result = requests.get(f"{LEADER_URL}/telemetry/gps")

        if pos_result.status_code == 200:

            data = pos_result.json()

            l_pos = data['info']['position']

            leader_lat = float(l_pos['lat'])
            leader_lon = float(l_pos['lon'])
            leader_alt = float(l_pos['alt'])

            print(f"[Lider] Lat: {leader_lat:.6f}, Lon: {leader_lon:.6f}")

            # 2. CALCULAR NOVA POSIÇÃO COM OFFSET

            delta_lat = OFFSET_NORTH / 111111.0
            delta_lon = OFFSET_EAST / (111111.0 * math.cos(math.radians(leader_lat)))

            target_lat = leader_lat + delta_lat
            target_lon = leader_lon + delta_lon

            raw_target_alt = (leader_alt - LEADER_HOME_ALT) + OFFSET_ALT
            target_alt = max(2.0, raw_target_alt)

            # 3. ENVIAR COMANDO DE MOVIMENTO (Go To)

            fly_data = {
                "lat": target_lat,
                "long": target_lon,
                "alt": target_alt,
            }

            follow_result = requests.post(f"{FOLLOWER_URL}/movement/go_to_gps", json=fly_data)
            if follow_result.status_code != 200:
                print(f"ERRO: Falha no movimento. Code: {follow_result.status_code}")
                print(f"Detalhe do erro: {follow_result.text}")
                sys.exit(0)

            print(f">> Movendo Seguidor para: {target_lat:.6f}, {target_lon:.6f}")

        else:
            print(f"ERRO: Não conseguiu ler o líder. Code: {pos_result.status_code}")

        return True
    except Exception as e:
        print(f"Erro no loop: {e}")
        return False
# --- BLOCO PRINCIPAL ---
if __name__ == "__main__":
    try:
        run_mission_tracker(FOLLOWER_URL, 2.0, setup, loop)
    except KeyboardInterrupt:
        # Captura Ctrl+C para pousar com segurança
        print("\n--- INTERRUPÇÃO DETECTADA ---")
        print("Iniciando RTL (Return to Land)...")
        requests.get(f"{FOLLOWER_URL}/command/rtl")
        print("Encerrando programa.")
        sys.exit(0)
