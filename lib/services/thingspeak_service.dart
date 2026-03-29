import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

/// Data model for a single ThingSpeak feed entry from the ESP32 hardware.
class ThingSpeakBinData {
  final double weight;       // Field 1: Weight in grams
  final double latitude;     // Field 2: GPS Latitude
  final double longitude;    // Field 3: GPS Longitude
  final int status;          // Field 4: 0=EMPTY, 1=MEDIUM, 2=HIGH, 3=FULL
  final DateTime createdAt;  // Timestamp of the entry

  ThingSpeakBinData({
    required this.weight,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
  });

  /// Weight in kilograms (hardware sends grams)
  double get weightKg => weight / 1000.0;

  /// Human-readable status string
  String get statusLabel {
    switch (status) {
      case 0: return 'EMPTY';
      case 1: return 'MEDIUM';
      case 2: return 'HIGH';
      case 3: return 'FULL';
      default: return 'UNKNOWN';
    }
  }

  /// Fill percentage (0.0 to 1.0) based on new weight thresholds
  double get fillPercentage {
    if (weight >= 600) return 1.0;
    if (weight >= 300) return 0.5;
    return weight / 600.0; // Linear fill for low weights
  }

  /// Color logic based on weight: 0=Green, 300=Yellow, 600=Red
  Color get statusColor {
    if (weight >= 600) return const Color(0xFFEF4444); // Red
    if (weight >= 300) return const Color(0xFFFBBF24); // Yellow
    return const Color(0xFF10B981); // Green
  }

  /// Whether GPS location has been acquired
  bool get hasLocation => latitude != 0.0 || longitude != 0.0;

  factory ThingSpeakBinData.fromFeedEntry(Map<String, dynamic> entry) {
    return ThingSpeakBinData(
      weight: double.tryParse(entry['field1']?.toString() ?? '0') ?? 0.0,
      latitude: double.tryParse(entry['field2']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(entry['field3']?.toString() ?? '0') ?? 0.0,
      status: int.tryParse(entry['field4']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(entry['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'BinData(weight: ${weight}g, lat: $latitude, lng: $longitude, status: $statusLabel)';
}

/// Service class to read data from ThingSpeak channel.
class ThingSpeakService {
  // ── Your ThingSpeak Channel Config ──
  static const int channelId = 3317901;
  static const String readAPIKey = 'IKVFXVWN10R2DPJJ';

  static const String _baseUrl = 'https://api.thingspeak.com';

  /// Fetch the latest single feed entry (most recent data from ESP32).
  static Future<ThingSpeakBinData?> fetchLatest() async {
    try {
      final url = Uri.parse(
        '$_baseUrl/channels/$channelId/feeds.json?api_key=$readAPIKey&results=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'] as List?;

        if (feeds != null && feeds.isNotEmpty) {
          return ThingSpeakBinData.fromFeedEntry(feeds.last);
        }
      }
      return null;
    } catch (e) {
      // Network error, timeout, etc.
      return null;
    }
  }

  /// Fetch the last N feed entries (for charts / history).
  static Future<List<ThingSpeakBinData>> fetchHistory({int results = 20}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/channels/$channelId/feeds.json?api_key=$readAPIKey&results=$results',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'] as List? ?? [];

        return feeds
            .map((entry) => ThingSpeakBinData.fromFeedEntry(entry))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch only a specific field's last value.
  static Future<String?> fetchField(int fieldNumber) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/channels/$channelId/fields/$fieldNumber/last.json?api_key=$readAPIKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['field$fieldNumber']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
