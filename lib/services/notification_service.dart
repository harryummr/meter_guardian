import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'meter_guardian_channel';
  static const _channelName = 'Meter Guardian Alerts';

  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Reminders and slab-crossing warnings for your meters',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  /// Immediate warning, e.g. when a meter crosses 150/180/190/195/199/200 units.
  Future<void> showThresholdAlert({
    required String meterName,
    required int threshold,
    required double unitsUsed,
  }) async {
    final id = ('threshold_$meterName$threshold').hashCode;
    String title;
    if (threshold >= 200) {
      title = '🔴 $meterName crossed 200 units!';
    } else if (threshold >= 195) {
      title = '🟠 $meterName: $threshold units — almost at the limit';
    } else if (threshold >= 180) {
      title = '🟡 $meterName: $threshold units — getting close';
    } else {
      title = '🟢 $meterName: $threshold units used';
    }
    await _plugin.show(
      id,
      title,
      'Current usage: ${unitsUsed.toStringAsFixed(1)} units on this billing cycle.',
      _details,
    );
  }

  Future<void> showHighAverageWarning({
    required String meterName,
    required double averagePerDay,
    required double daysUntil200,
  }) async {
    final id = ('avg_$meterName').hashCode;
    await _plugin.show(
      id,
      '⚠️ $meterName consumption is high',
      'Averaging ${averagePerDay.toStringAsFixed(1)} units/day — '
          'at this rate you\'ll hit 200 units in about '
          '${daysUntil200.toStringAsFixed(1)} days.',
      _details,
    );
  }

  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    await _plugin.zonedSchedule(
      1001,
      'Meter Guardian reminder',
      'Don\'t forget to scan today\'s meter readings.',
      _nextInstanceOfTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWeeklyReminder({
    int weekday = DateTime.sunday,
    int hour = 19,
    int minute = 0,
  }) async {
    await _plugin.zonedSchedule(
      1002,
      'Weekly meter check-in',
      'Review this week\'s electricity usage across all your meters.',
      _nextInstanceOfWeekday(weekday, hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
