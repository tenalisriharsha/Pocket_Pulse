import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Local notifications for PocketPulse (macOS-friendly).
///
/// Zero-spam rules:
/// - Schedule at most ONE notification per recurring rule (its next due).
/// - If rule is overdue: do NOT auto-notify (UI will show overdue), cancel it.
/// - If rule is outside the window: cancel it.
/// - Sync is idempotent.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzReady = false;

  Set<int> _lastScheduledRuleIds = {};

  static const int _testNotificationId = 990001;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const init = InitializationSettings(macOS: darwinInit);
    await _plugin.initialize(init);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await ensureInitialized();

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();

    final ok = await macos?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;

    return ok;
  }

  Future<void> _ensureTzReady() async {
    if (_tzReady) return;

    tzdata.initializeTimeZones();
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));

    _tzReady = true;
  }

  Future<void> syncUpcomingRules({
    required List<({int id, String name, DateTime nextDueDate})> rules,
    required int daysAhead,
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0),
  }) async {
    await ensureInitialized();
    await _ensureTzReady();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endInclusive = today.add(Duration(days: daysAhead));

    final upcomingIds = rules.map((r) => r.id).toSet();

    final toCancel = _lastScheduledRuleIds.difference(upcomingIds);
    for (final id in toCancel) {
      await _plugin.cancel(_recurringNotificationId(id));
    }

    for (final r in rules) {
      final due = r.nextDueDate;
      final dueDay = DateTime(due.year, due.month, due.day);

      if (dueDay.isBefore(today)) {
        await _plugin.cancel(_recurringNotificationId(r.id));
        continue;
      }

      if (dueDay.isAfter(endInclusive)) {
        await _plugin.cancel(_recurringNotificationId(r.id));
        continue;
      }

      final scheduledAt = _computeReminderDateTime(
        due,
        reminderTime: reminderTime,
        now: now,
      );

      if (!scheduledAt.isAfter(now)) {
        await _plugin.cancel(_recurringNotificationId(r.id));
        continue;
      }

      await _scheduleOneShot(
        ruleId: r.id,
        name: r.name,
        scheduledAt: scheduledAt,
      );
    }

    _lastScheduledRuleIds = upcomingIds;
  }

  /// Test notification (fires after [delay]).
  Future<void> scheduleTestNotification({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await ensureInitialized();
    await _ensureTzReady();

    await _plugin.cancel(_testNotificationId);

    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final when = tz.TZDateTime.from(DateTime.now().add(delay), tz.local);

    await _plugin.zonedSchedule(
      _testNotificationId,
      'PocketPulse test reminder',
      'If you see this, notifications are working ✅',
      when,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    _lastScheduledRuleIds.clear();
  }

  // ---------------- internals ----------------

  int _recurringNotificationId(int ruleId) => 100000 + ruleId;

  DateTime _computeReminderDateTime(
    DateTime due, {
    required TimeOfDay reminderTime,
    required DateTime now,
  }) {
    final dueDay = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);

    final preferred = DateTime(
      dueDay.year,
      dueDay.month,
      dueDay.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    if (dueDay == today && !preferred.isAfter(now)) {
      return now.add(const Duration(minutes: 1));
    }

    return preferred;
  }

  Future<void> _scheduleOneShot({
    required int ruleId,
    required String name,
    required DateTime scheduledAt,
  }) async {
    await _plugin.cancel(_recurringNotificationId(ruleId));

    final title = 'Recurring due: $name';
    const body = 'Open PocketPulse to mark it as paid.';

    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final tzWhen = tz.TZDateTime.from(scheduledAt, tz.local);

    await _plugin.zonedSchedule(
      _recurringNotificationId(ruleId),
      title,
      body,
      tzWhen,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }
}