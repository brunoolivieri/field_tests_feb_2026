# 🧪 Field Tests - February 2026

![Status](https://img.shields.io/badge/Status-Active-success)
![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![Field Test](https://img.shields.io/badge/Type-Field_Test-orange)

Welcome to the **Field Tests - February 2026** repository. This centralized hub is dedicated to storing, versioning, and analyzing all results and tools used during the field testing campaigns conducted in February 2026. The repository ensures data consistency and provides a snapshot of the exact software versions used during the tests.

---

## 📂 Repository Structure

The repository is organized into distinct components for hardware communication, logging, and control software. Below is the breakdown of the current directories:

| Folder Name | Component Category | Description |
| :--- | :--- | :--- |
| **`/drone_api`** | 🚁 **Drone Control** | API interfaces and libraries for communicating with and controlling the drones. |
| **`/drones_logs`** | 📊 **Drone Data** | Flight logs, sensor telemetry, and debug data recorded directly from the drones. |
| **`/esp32_code`** | 📟 **Firmware** | Source code and firmware binaries for the ESP32 microcontrollers used in the field. |
| **`/esp32_logs`** | 📝 **Sensor Logs** | Data logs captured from ESP32 sensors and devices during operation. |
| **`/groundStation_logs`** | 🖥️ **Station Logs** | Operational logs, command history, and system status from the Ground Control Station. |
| **`/groundStation_software`** | 💻 **Control Software** | The main application suite for the Ground Station, including UI and telemetry processing. |
| **`/network`** | 📡 **Connectivity** | Network configurations, setup scripts, and definitions for the field communication mesh. |
| **`/rpi_esp32_collector`** | 🍓 **Data Collection** | Scripts running on the Raspberry Pi to collect and aggregate data from ESP32 nodes. |

---

## 🚀 Getting Started

To utilize this repository's resources or analyze field data:

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/brunoolivieri/field_tests_feb_2026.git
    cd field_tests_feb_2026
    ```

2.  **Access Logs**:
    Navigate to the `*_logs` directories (e.g., `/drones_logs`, `/esp32_logs`) to process raw data from specific test runs.

3.  **Deploy Tools**:
    Use the code in `/esp32_code` or `/drone_api` to reproduce the exact software environment used during the tests.

## 📌 Usage Guidelines

*   **Log Integrity**: The `*_logs` folders contain raw evidence. **Do not modify these files** manually.
*   **Version Control**: This repository captures the state of the software *as used in the field*. Do not update dependencies unless preparing for a new test cycle.

---

> *Note: This repository structure reflects the active components of the February 2026 deployment. For questions specifically about the drone or sensor integration, refer to the respective subdirectories.*
