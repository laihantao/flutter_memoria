import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  static Future<void> scheduleBirthdayReminder({
    required int notificationId,
    required String personName,
    required DateTime birthday,
  }) async {
    if (kIsWeb) return;
    await _cancelIfExists(notificationId);

    final next = _nextOccurrence(birthday);
    if (next == null) return;

    await _plugin.zonedSchedule(
      notificationId,
      '🎂 $personName\'s birthday today!',
      'Don\'t forget to wish them well.',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthdays',
          'Birthday Reminders',
          channelDescription: 'Reminds you of contacts\' birthdays',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static Future<void> scheduleAnniversaryReminder({
    required int notificationId,
    required String label,
    required DateTime anniversary,
  }) async {
    if (kIsWeb) return;
    await _cancelIfExists(notificationId);

    final next = _nextOccurrence(anniversary);
    if (next == null) return;

    await _plugin.zonedSchedule(
      notificationId,
      '💑 $label anniversary today!',
      'A special day to celebrate.',
      tz.TZDateTime.from(next, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'anniversaries',
          'Anniversary Reminders',
          channelDescription: 'Reminds you of anniversaries',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static Future<void> cancel(int notificationId) async {
    if (kIsWeb) return;
    await _plugin.cancel(notificationId);
  }

  static Future<void> _cancelIfExists(int id) => _plugin.cancel(id);

  /// Returns next occurrence of [date] at 9:00 AM, null if invalid.
  static DateTime? _nextOccurrence(DateTime date) {
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day, 9);
    if (next.isBefore(now)) {
      next = DateTime(now.year + 1, date.month, date.day, 9);
    }
    return next;
  }

  static int birthdayNotificationId(String personId) =>
      personId.hashCode & 0x7FFFFFFF;

  static int anniversaryNotificationId(String anniversaryId) =>
      ('ann_$anniversaryId').hashCode & 0x7FFFFFFF;
}
