import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// Callback for handling notification taps (must be top-level for background)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background tap handler — used for navigation when app is killed
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _audioPlayer = AudioPlayer();
  static Timer? _repeatTimer;
  static bool _isBuzzerPlaying = false;

  /// Stored bin location for navigation on notification tap
  static double? _lastAlertLat;
  static double? _lastAlertLng;
  static String? _lastAlertLocation;

  /// Callback for when user taps notification (set from UI layer)
  static void Function(double lat, double lng, String location)? onNavigateToBin;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create the high-priority notification channel for Android
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'full_bin_alert_channel',
          'Full Bin Alerts',
          description: 'Emergency notifications when bins are full and need collection',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
    }
  }

  /// Handle notification tap — navigates worker to bin location
  static void _onNotificationTapped(NotificationResponse response) {
    if (_lastAlertLat != null && _lastAlertLng != null && _lastAlertLocation != null) {
      onNavigateToBin?.call(_lastAlertLat!, _lastAlertLng!, _lastAlertLocation!);
    }
  }

  /// 🚨 FULL BIN ALERT — High-priority notification with buzzer and location
  static Future<void> showFullBinAlert({
    required String binLocation,
    required String binId,
    double? latitude,
    double? longitude,
    double? weight,
  }) async {
    // Store location for navigation
    _lastAlertLat = latitude;
    _lastAlertLng = longitude;
    _lastAlertLocation = binLocation;

    final weightStr = weight != null ? '${weight.toStringAsFixed(1)}g' : '200g+';

    const androidDetails = AndroidNotificationDetails(
      'full_bin_alert_channel',
      'Full Bin Alerts',
      channelDescription: 'Emergency notifications for full bins',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      ongoing: true, // Keeps notification visible until dismissed
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'BIN FULL — Collect Now!',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      binId.hashCode,
      '🚨 BIN IS FULL — COLLECT NOW!',
      '📍 Location: $binLocation\n⚖️ Weight: $weightStr\nTap to navigate to the bin location.',
      details,
      payload: 'bin_full:$binId',
    );

    // 🔊 Play persistent buzzer alarm (repeats 5 times)
    await _playRepeatingBuzzer();
  }

  /// Shows a quick status notification (non-emergency)
  static Future<void> showStatusNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bin_status_channel',
      'Bin Status Updates',
      channelDescription: 'Non-urgent bin status notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );
  }

  /// 🔊 Repeating buzzer sound — plays alarm 5 times with 1s gap
  static Future<void> _playRepeatingBuzzer() async {
    if (_isBuzzerPlaying) return; // Prevent overlapping buzzers
    _isBuzzerPlaying = true;

    int count = 0;
    _repeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (count >= 5) {
        timer.cancel();
        _isBuzzerPlaying = false;
        return;
      }
      try {
        await _audioPlayer.stop();
        // Try asset sound first, fallback to URL-based alert tone
        try {
          await _audioPlayer.play(AssetSource('sounds/buzzer.mp3'));
        } catch (_) {
          // Fallback: use a web-based alert sound
          await _audioPlayer.play(UrlSource(
            'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg',
          ));
        }
      } catch (_) {
        // Final fallback: silent (notification vibration still works)
      }
      count++;
    });
  }

  /// 🔇 Stop the buzzer immediately
  static Future<void> stopBuzzer() async {
    _repeatTimer?.cancel();
    _isBuzzerPlaying = false;
    await _audioPlayer.stop();
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await stopBuzzer();
  }
}
