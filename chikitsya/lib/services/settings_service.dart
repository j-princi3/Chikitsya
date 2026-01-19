import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _medicineReminders = 'medicine_reminders';
  static const _followUpAlerts = 'followup_alerts';
  static const _largeText = 'large_text';
  static const _language = 'language';

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  Future<bool> getMedicineReminders() async =>
      (await _prefs()).getBool(_medicineReminders) ?? true;

  Future<bool> getFollowUpAlerts() async =>
      (await _prefs()).getBool(_followUpAlerts) ?? true;

  Future<bool> getLargeText() async =>
      (await _prefs()).getBool(_largeText) ?? false;

  Future<String> getLanguage() async =>
      (await _prefs()).getString(_language) ?? 'English';

  Future<void> setMedicineReminders(bool value) async =>
      (await _prefs()).setBool(_medicineReminders, value);

  Future<void> setFollowUpAlerts(bool value) async =>
      (await _prefs()).setBool(_followUpAlerts, value);

  Future<void> setLargeText(bool value) async =>
      (await _prefs()).setBool(_largeText, value);

  Future<void> setLanguage(String value) async =>
      (await _prefs()).setString(_language, value);
}
