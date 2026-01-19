import 'dart:developer' as developer;

import '../models/reminder_model.dart';

List<Reminder> mapSummaryToReminders(Map<String, dynamic> bundle) {
  final entries = (bundle["entry"] ?? []) as List;

  // Find Composition
  final compositionEntry = entries.firstWhere(
    (e) => (e["resource"]?["resourceType"] == "Composition"),
    orElse: () => null,
  );
  final composition = compositionEntry?["resource"] as Map<String, dynamic>?;
  final sections = (composition?["section"] ?? []) as List;

  // Find medications section
  final medSection = sections.firstWhere(
    (s) => s["title"] == "Medications",
    orElse: () => {"entry": []},
  );
  final medRefs = (medSection["entry"] ?? []) as List;

  // Helper to get resources by reference
  Map<String, dynamic> getResource(String ref) {
    final parts = ref.split("/");
    final id = parts[1];
    final type = parts[0];
    return entries.firstWhere(
      (e) => e["resource"]["resourceType"] == type && e["resource"]["id"] == id,
      orElse: () => {"resource": {}},
    )["resource"];
  }

  final meds = medRefs.map((ref) {
    final resRef = ref["reference"] as String;
    return getResource(resRef);
  }).toList();

  final now = DateTime.now();
  final List<Reminder> reminders = [];

  int id = 0;

  for (final med in meds) {
    final name = med['medicationCodeableConcept']?['text'];
    final exactTimes =
        (med['exact_time'] ?? []) as List; // Assuming AI adds this
    final dosage = med['dosage'] as String?; // Extract dosage information

    if (name == null || exactTimes.isEmpty) {
      developer.log("⚠️ Skipping med (missing name/exact_time): $med");
      continue;
    }

    for (final timeStr in exactTimes) {
      if (timeStr is! String) continue;

      try {
        // Parse time like "8:00 AM" or "2:00 PM"
        final timeParts = timeStr.split(' ');
        if (timeParts.length != 2) continue;

        final time = timeParts[0].split(':');
        if (time.length != 2) continue;

        int hour = int.parse(time[0]);
        int minute = int.parse(time[1]);
        final period = timeParts[1].toUpperCase();

        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;

        DateTime reminderTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        // If the time is in the past, schedule for tomorrow
        if (reminderTime.isBefore(now)) {
          reminderTime = reminderTime.add(const Duration(days: 1));
        }

        reminders.add(
          Reminder(
            id: id++,
            title: "Take $name",
            time: reminderTime,
            isCritical: false,
            dosage: dosage,
          ),
        );
      } catch (e) {
        developer.log("⚠️ Failed to parse time '$timeStr' for $name: $e");
      }
    }
  }

  return reminders;
}
