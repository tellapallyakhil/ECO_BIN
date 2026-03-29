import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final _audioPlayer = AudioPlayer();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification click (go to bin location)
      },
    );
  }

  /// 🚨 Broadcasters the "FULL BIN" Alert with Buzzer Sound
  static Future<void> showFullBinAlert({required String binLocation, required String binId}) async {
    const androidDetails = AndroidNotificationDetails(
      'full_bin_alert_channel',
      'Full Bin Alerts',
      channelDescription: 'Emergency notifications for full bins',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm, // 💡 Makes it loud like an alarm
      fullScreenIntent: true, // 💡 Wakes up the screen
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      binId.hashCode, // Unique ID per bin
      '⚠️ BIN FULL DETECTED!',
      'Bin at $binLocation is ready for collection (600g).',
      details,
    );

    // 🔊 PLAY BUZZER SOUND
    await _playBuzzer();
  }

  static Future<void> _playBuzzer() async {
    try {
      // Plays a fallback system sound or a custom buzzer if provided
      // For now, we'll use a built-in alarm-like sound
      await _audioPlayer.play(AssetSource('sounds/buzzer.mp3'));
    } catch (e) {
      // Fallback to system tone if file missing
    }
  }

  static Future<void> stopBuzzer() async {
    await _audioPlayer.stop();
  }
}
