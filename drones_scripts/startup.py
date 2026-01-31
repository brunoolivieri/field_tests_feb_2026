from helpers.init_api import init_api

if __name__ == "__main__":
    print("Iniciando API do drone...")
    api_process = init_api()
    print("API iniciada com sucesso.")

    api_process.wait()