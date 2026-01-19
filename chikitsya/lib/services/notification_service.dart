import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'database_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onResponse,
    );
  }

  static Future<void> schedule({
    required int id,
    required String title,
    required DateTime time,
    required bool critical,
  }) async {
    final android = AndroidNotificationDetails(
      critical ? 'critical' : 'normal',
      critical ? 'Critical Reminders' : 'Regular Reminders',
      importance: critical ? Importance.max : Importance.defaultImportance,
      priority: critical ? Priority.high : Priority.defaultPriority,
      color: critical ? Colors.red : Colors.blue,
      actions: const [
        AndroidNotificationAction('YES', 'Taken'),
        AndroidNotificationAction('NO', 'Skipped'),
      ],
    );

    await _plugin.zonedSchedule(
      id,
      'Medication Reminder',
      title,
      tz.TZDateTime.from(time, tz.local),
      NotificationDetails(android: android),
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  static void _onResponse(NotificationResponse response) {
    if (response.actionId == 'YES') {
      DatabaseService.saveAdherence(response.payload ?? '', true);
    }
    if (response.actionId == 'NO') {
      DatabaseService.saveAdherence(response.payload ?? '', false);
    }
  }
}
