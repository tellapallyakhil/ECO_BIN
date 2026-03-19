# EcoBin Hardware Integration Guide

This project uses an **ESP32** microcontroller coupled with sensors to create a "Smart Bin".

## Bill of Materials (BOM)
- **ESP32 DevKit V1**
- **HC-SR04 Ultrasonic Sensor** (Fill Level)
- **HX711 Load Cell Amplifier** + **5kg-50kg Load Cell** (Weight)
- **Jumper Wires & Breadboard**

## Wiring Diagram
### 1. Ultrasonic Sensor (Fill Level)
| HC-SR04 | ESP32 |
| :--- | :--- |
| VCC | 5V / VIN |
| TRIG | GPIO 5 |
| ECHO | GPIO 18 |
| GND | GND |

### 2. HX711 (Weight)
| HX711 | ESP32 |
| :--- | :--- |
| VCC | 3.3V / 5V |
| DT (Data) | GPIO 21 |
| SCK (Clock)| GPIO 22 |
| GND | GND |

## Setup Instructions
1.  **Install Arduino IDE**: Download from [arduino.cc](https://www.arduino.cc/en/software).
2.  **Install ESP32 Board**: Add `https://dl.espressif.com/dl/package_esp32_index.json` to Additional Board Manager URLs in Preferences.
3.  **Install Libraries**: 
    - Search and install **HX711 Arduino Library** by Bogdan Necula.
4.  **Open `eco_bin_hardware.ino`**: Load the provided file in the root directory.
5.  **Configure WiFi**: Update the `ssid` and `password` variables in the code.
6.  **Calibrate**: Use a known weight (e.g., 1kg) to adjust the `calibration_factor` until the output is accurate.

## Software Logic
The code reads the bin's "fullness" using ultrasonic waves and calculate the weight of the waste using the load cell. It then pushes this data to your Supabase backend every few seconds via a JSON payload.
