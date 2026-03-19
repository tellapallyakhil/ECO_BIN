/*
 * EcoBin: Smart Waste Management System
 * Hardware Code for ESP32
 * 
 * Components:
 * 1. HC-SR04 Ultrasonic Sensor (Fill Level)
 * 2. HX711 + Load Cell (Weight Measurement)
 * 3. ESP32 (Microcontroller)
 */

#include "HX711.h"
#include <WiFi.h>
#include <HTTPClient.h>

// WiFi Configuration
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// API Configuration (Optional)
const char* apiEndpoint = "https://your-api-endpoint.com/update-bin";
const String binId = "BIN-101";

// Pin Definitions
const int trigPin = 5;
const int echoPin = 18;
const int hx711_dout = 21;
const int hx711_sck = 22;

// Constraints
const int binHeight = 100; // Total height of bin in cm
const float calibration_factor = 2280.0; // Adjust after hardware calibration

HX711 scale;

void setup() {
  Serial.begin(115200);
  
  // Ultrasonic setup
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  
  // Scale setup
  scale.begin(hx711_dout, hx711_sck);
  scale.set_scale(calibration_factor);
  scale.tare(); // Zero the scale at startup
  
  // WiFi setup
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
}

void loop() {
  // 1. Measure Fill Level using Ultrasonic
  long duration;
  int distance;
  
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  duration = pulseIn(echoPin, HIGH);
  distance = duration * 0.034 / 2;
  
  // Calculate Fill Percentage
  int fillPercentage = map(distance, binHeight, 5, 0, 100);
  fillPercentage = constrain(fillPercentage, 0, 100);
  
  // 2. Measure Weight
  float weight = scale.get_units(5); // Average of 5 readings
  if (weight < 0) weight = 0; // Prevent noise
  
  // 3. Output to Serial
  Serial.print("Bin ID: "); Serial.println(binId);
  Serial.print("Fill: "); Serial.print(fillPercentage); Serial.println("%");
  Serial.print("Weight: "); Serial.print(weight, 2); Serial.println(" kg");
  Serial.println("--------------------------");

  // 4. Send Data to Server (if connected)
  if (WiFi.status() == WL_CONNECTED) {
    sendDataToServer(fillPercentage, weight);
  }

  delay(5000); // Update every 5 seconds
}

void sendDataToServer(int fill, float weight) {
  HTTPClient http;
  http.begin(apiEndpoint);
  http.addHeader("Content-Type", "application/json");
  
  String jsonData = "{\"binId\":\"" + binId + 
                    "\", \"fill_pct\":" + String(fill) + 
                    ", \"weight\":" + String(weight) + "}";
                    
  int httpResponseCode = http.POST(jsonData);
  
  if (httpResponseCode > 0) {
    Serial.print("HTTP Response code: ");
    Serial.println(httpResponseCode);
  } else {
    Serial.print("Error code: ");
    Serial.println(httpResponseCode);
  }
  http.end();
}
