import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderTimeMinutes = 'pp_reminder_time_minutes';
const _kRemindersEnabled = 'pp_reminders_enabled';

int _timeToMinutes(TimeOfDay t) => (t.hour * 60) + t.minute;

TimeOfDay _minutesToTime(int minutes) {
  final m = minutes.clamp(0, (23 * 60) + 59);
  return TimeOfDay(hour: m ~/ 60, minute: m % 60);
}

/// User-configurable reminder time (default: 9:00 AM)
final reminderTimeProvider =
    AsyncNotifierProvider<ReminderTimeNotifier, TimeOfDay>(ReminderTimeNotifier.new);

class ReminderTimeNotifier extends AsyncNotifier<TimeOfDay> {
  @override
  Future<TimeOfDay> build() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_kReminderTimeMinutes) ?? (9 * 60);
    return _minutesToTime(minutes);
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderTimeMinutes, _timeToMinutes(time));
    state = AsyncData(time);
  }
}

/// Enable/Disable recurring reminders (default: false)
final remindersEnabledProvider =
    AsyncNotifierProvider<RemindersEnabledNotifier, bool>(RemindersEnabledNotifier.new);

class RemindersEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRemindersEnabled) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemindersEnabled, enabled);
    state = AsyncData(enabled);
  }
}