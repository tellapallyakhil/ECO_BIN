/*
 * EcoBin: Smart Waste Management System
 * Hardware Code for ESP32 + ThingSpeak Integration
 *
 * Components:
 * 1. HX711 Load Cell (Weight Measurement)
 * 2. GPS Module (NEO-6M via UART2)
 * 3. LEDs (Green, Yellow, Red for bin status)
 * 4. ESP32 (Microcontroller)
 *
 * ThingSpeak Channel Fields:
 *   Field 1 = Weight (grams)
 *   Field 2 = Latitude
 *   Field 3 = Longitude
 *   Field 4 = Status (0=EMPTY, 1=MEDIUM, 2=HIGH, 3=FULL)
 */

#include "HX711.h"
#include <HTTPClient.h>
#include <HardwareSerial.h>
#include <TinyGPS++.h>
#include <WiFi.h>

// ============ WiFi Configuration ============
const char *ssid = "YOUR_WIFI_SSID";         // ← Change this
const char *password = "YOUR_WIFI_PASSWORD"; // ← Change this

// ============ ThingSpeak Configuration ============
const char *thingSpeakServer = "http://api.thingspeak.com/update";
const char *writeAPIKey = "B1MBE4HMNSO6QDC1"; // Your Write API Key

// ============ HX711 Pins ============
#define DT 21
#define SCK_PIN 22

// ============ LED Pins ============
#define GREEN_LED 2
#define YELLOW_LED 19
#define RED_LED 4

// ============ GPS Pins (UART2) ============
#define GPS_RX 16
#define GPS_TX 17

// ============ Objects ============
HX711 scale;
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

// ============ Calibration & Thresholds ============
float calibration_factor = 46.5;

// Thresholds (Grams)
float lowLevel = 0.0;
float midLevel = 500.0;
float highLevel = 600.0;

// ============ Timing ============
unsigned long lastThingSpeakUpdate = 0;
const unsigned long THINGSPEAK_INTERVAL =
    15000; // 15 seconds (free tier minimum)

// ============ Stored Values ============
float lastWeight = 0.0;
double lastLat = 0.0;
double lastLng = 0.0;
int lastStatus = 0; // 0=EMPTY, 1=MEDIUM, 2=HIGH, 3=FULL

void setup() {
  Serial.begin(115200);
  Serial.println("\n=============================");
  Serial.println("  EcoBin Starting Up...");
  Serial.println("=============================");

  // HX711 setup
  scale.begin(DT, SCK_PIN);
  scale.set_scale(calibration_factor);
  scale.tare();
  Serial.println("✅ HX711 Load Cell initialized");

  // LED setup
  pinMode(GREEN_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  Serial.println("✅ LED indicators ready");

  // GPS Serial
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println("✅ GPS module initialized (UART2)");

  // WiFi setup
  Serial.print("📡 Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);

  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 40) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi Connected!");
    Serial.print("   IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n⚠️ WiFi failed! Data will only show on Serial.");
    Serial.println("   (Will keep retrying in background)");
  }

  Serial.println("\n=============================");
  Serial.println("  System Ready!");
  Serial.println("  Type 't' to tare/zero scale");
  Serial.println("=============================\n");
}

void loop() {
  // Check for tare command
  if (Serial.available()) {
    char input = Serial.read();
    if (input == 't' || input == 'T') {
      scale.tare();
      Serial.println("⚖️ Scale reset to 0");
    }
  }

  // ===== 1. Read Weight =====
  float weight = scale.get_units(10);
  weight = weight / 10.0;
  if (weight < 0)
    weight = 0; // prevent negative noise
  lastWeight = weight;

  Serial.print("Weight: ");
  Serial.print(weight, 1);
  Serial.println(" g");

  // ===== 2. Determine Status & Control LEDs =====
  if (weight < lowLevel) {
    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(YELLOW_LED, LOW);
    digitalWrite(RED_LED, LOW);
    lastStatus = 0;
    Serial.println("Status: EMPTY");
  } else if (weight < midLevel) {
    digitalWrite(GREEN_LED, LOW);
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(RED_LED, LOW);
    lastStatus = 1;
    Serial.println("Status: MEDIUM");
  } else if (weight < highLevel) {
    digitalWrite(GREEN_LED, LOW);
    digitalWrite(YELLOW_LED, LOW);
    digitalWrite(RED_LED, HIGH);
    lastStatus = 2;
    Serial.println("Status: HIGH");
  } else {
    digitalWrite(GREEN_LED, LOW);
    digitalWrite(YELLOW_LED, LOW);
    digitalWrite(RED_LED, HIGH);
    lastStatus = 3;
    Serial.println("⚠️ BIN FULL!");
  }

  // ===== 3. Read GPS =====
  while (gpsSerial.available()) {
    gps.encode(gpsSerial.read());
  }

  if (gps.location.isValid()) {
    lastLat = gps.location.lat();
    lastLng = gps.location.lng();
    Serial.print("📍 Lat: ");
    Serial.println(lastLat, 6);
    Serial.print("📍 Lng: ");
    Serial.println(lastLng, 6);
  } else {
    Serial.println("📍 Waiting for GPS fix...");
  }

  // ===== 4. Send to ThingSpeak (every 15 sec) =====
  unsigned long now = millis();
  if (now - lastThingSpeakUpdate >= THINGSPEAK_INTERVAL) {
    lastThingSpeakUpdate = now;
    sendToThingSpeak();
  }

  Serial.println("----------------------");
  delay(1000);
}

// ============ ThingSpeak Upload ============
void sendToThingSpeak() {
  // Reconnect WiFi if disconnected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("📡 WiFi disconnected, reconnecting...");
    WiFi.begin(ssid, password);
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 10) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\n❌ WiFi reconnect failed, skipping upload.");
      return;
    }
    Serial.println("\n✅ WiFi reconnected!");
  }

  HTTPClient http;

  // Build ThingSpeak URL with all 4 fields
  String url = String(thingSpeakServer);
  url += "?api_key=" + String(writeAPIKey);
  url += "&field1=" + String(lastWeight, 1); // Weight in grams
  url += "&field2=" + String(lastLat, 6);    // Latitude
  url += "&field3=" + String(lastLng, 6);    // Longitude
  url += "&field4=" + String(lastStatus);    // Status code

  Serial.println("📤 Sending to ThingSpeak...");

  http.begin(url);
  int httpCode = http.GET();

  if (httpCode > 0) {
    String response = http.getString();
    Serial.print("✅ ThingSpeak Response: ");
    Serial.println(response); // Returns entry ID on success, 0 on failure

    if (response.toInt() == 0) {
      Serial.println("⚠️ ThingSpeak rejected data (rate limit or invalid key)");
    }
  } else {
    Serial.print("❌ HTTP Error: ");
    Serial.println(httpCode);
  }

  http.end();
}
