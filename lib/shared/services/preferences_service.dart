import 'package:shared_preferences/shared_preferences.dart';

/// Simple key-value storage for user preferences.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const _kReminderTimeMinutes = 'reminder_time_minutes';

  // Default reminder time: 9:00 AM -> 9*60 = 540
  static const int defaultReminderMinutes = 9 * 60;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<int> getReminderTimeMinutes() async {
    final prefs = await _prefs;
    return prefs.getInt(_kReminderTimeMinutes) ?? defaultReminderMinutes;
  }

  Future<void> setReminderTimeMinutes(int minutesFromMidnight) async {
    final prefs = await _prefs;
    await prefs.setInt(_kReminderTimeMinutes, minutesFromMidnight);
  }
}