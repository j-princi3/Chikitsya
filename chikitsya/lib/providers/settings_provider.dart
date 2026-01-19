import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  bool medicineReminders = true;
  bool followUpAlerts = true;
  bool largeText = false;
  String language = 'English';

  Locale get locale {
    switch (language) {
      case 'Hindi':
        return const Locale('hi');
      case 'Telugu':
        return const Locale('te');
      default:
        return const Locale('en');
    }
  }

  Future<void> loadSettings() async {
    medicineReminders = await _service.getMedicineReminders();
    followUpAlerts = await _service.getFollowUpAlerts();
    largeText = await _service.getLargeText();
    language = await _service.getLanguage();
    notifyListeners();
  }

  Future<void> toggleMedicineReminders(bool value) async {
    medicineReminders = value;
    await _service.setMedicineReminders(value);
    notifyListeners();
  }

  Future<void> toggleFollowUpAlerts(bool value) async {
    followUpAlerts = value;
    await _service.setFollowUpAlerts(value);
    notifyListeners();
  }

  Future<void> toggleLargeText(bool value) async {
    largeText = value;
    await _service.setLargeText(value);
    notifyListeners();
  }

  Future<void> changeLanguage(String value) async {
    language = value;
    await _service.setLanguage(value);
    notifyListeners();
  }
}
