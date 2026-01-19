import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';

import '../models/reminder_model.dart';
import 'notification_service.dart';
import 'database_service.dart';

class ReminderService {
  static Future<void> processAndSchedule(List<Reminder> reminders) async {
    // Request exact alarm permission if needed
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    for (final r in reminders) {
    for (final r in reminders) {
      // 1️Schedule notification
      await NotificationService.schedule(
        id: r.id,
        title: r.title,
        time: r.time,
        critical: r.isCritical,
      );

      // 2 Store reminder locally
      await DatabaseService.saveReminder(r);
      developer.log("Reminders saved");
    }
    }
  }
}
