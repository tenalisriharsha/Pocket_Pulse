import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocket_pulse/features/accounts/accounts_page.dart';
import 'package:pocket_pulse/features/debug/db_debug_page.dart';

import 'package:pocket_pulse/shared/animations/confetti_overlay.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/hover_card.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/shared/providers/reminder_time_provider.dart';
import 'package:pocket_pulse/shared/services/notification_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _fmtTime(BuildContext context, TimeOfDay t) {
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }

  Future<void> _resyncNow(WidgetRef ref, {required int daysAhead}) async {
    final enabled = ref.read(remindersEnabledProvider).valueOrNull ?? false;
    if (!enabled) return;

    final reminderTime =
        ref.read(reminderTimeProvider).valueOrNull ?? const TimeOfDay(hour: 9, minute: 0);

    final db = ref.read(databaseProvider);
    final rows = await db.recurringRulesDao.watchUpcoming(daysAhead: daysAhead).first;

    final upcoming = rows
        .where((r) => r.rule.isActive)
        .map((r) => (
              id: r.rule.id,
              name: r.rule.name,
              nextDueDate: r.rule.nextDueDate,
            ))
        .toList();

    await NotificationService.instance.syncUpcomingRules(
      rules: upcoming,
      daysAhead: daysAhead,
      reminderTime: reminderTime,
    );
  }

  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This will permanently delete all transactions, accounts, categories, budgets, and recurring rules. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.customStatement('DELETE FROM transaction_splits;');
    await db.customStatement('DELETE FROM transactions;');
    await db.customStatement('DELETE FROM budgets;');
    await db.customStatement('DELETE FROM recurring_rules;');
    await db.customStatement('DELETE FROM accounts;');
    await db.customStatement('DELETE FROM categories;');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(remindersEnabledProvider);
    final reminderAsync = ref.watch(reminderTimeProvider);

    final enabled = enabledAsync.valueOrNull ?? false;
    final reminderTime = reminderAsync.valueOrNull ?? const TimeOfDay(hour: 9, minute: 0);
    final reminderLabel = _fmtTime(context, reminderTime);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(title: 'Notifications'),

          FadeSlideIn(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Enable recurring reminders'),
                    subtitle: Text(
                      enabled
                          ? _lastingSubtitle(reminderLabel)
                          : 'Off \u2014 no reminders will be scheduled.',
                    ),
                    value: enabled,
                    onChanged: (v) async {
                      if (v) {
                        final ok = await NotificationService.instance.requestPermissions();
                        if (!ok) {
                          await ref.read(remindersEnabledProvider.notifier).setEnabled(false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notifications are disabled. Enable in macOS System Settings \u2192 Notifications.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        await ref.read(remindersEnabledProvider.notifier).setEnabled(true);
                        await _resyncNow(ref, daysAhead: 30);
                        if (context.mounted) {
                          ConfettiHelper.burst(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recurring reminders enabled')),
                          );
                        }
                      } else {
                        await ref.read(remindersEnabledProvider.notifier).setEnabled(false);
                        await NotificationService.instance.cancelAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recurring reminders disabled')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: const Text('Reminder time'),
                    subtitle: Text(
                      enabled ? 'Recurring reminders will fire at $reminderLabel' : 'Enable reminders to choose a time',
                    ),
                    trailing: Text(reminderLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    enabled: enabled,
                    onTap: !enabled
                        ? null
                        : () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: reminderTime,
                            );
                            if (picked == null) return;
                            await ref.read(reminderTimeProvider.notifier).setReminderTime(picked);
                            await _resyncNow(ref, daysAhead: 30);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reminder time set to ${_fmtTime(context, picked)}')),
                              );
                            }
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notification_add_outlined),
                    title: const Text('Test notification'),
                    subtitle: const Text('Fires in 10 seconds'),
                    enabled: enabled,
                    onTap: !enabled
                        ? null
                        : () async {
                            await NotificationService.instance.scheduleTestNotification(
                              delay: const Duration(seconds: 10),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test notification scheduled (10 seconds)')),
                              );
                            }
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync_outlined),
                    title: const Text('Resync reminders'),
                    subtitle: const Text('Re-schedule all active recurring notifications'),
                    enabled: enabled,
                    onTap: !enabled
                        ? null
                        : () async {
                            await _resyncNow(ref, daysAhead: 30);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reminders resynced')),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),

          const _SectionHeader(title: 'Appearance'),

          FadeSlideIn(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(_themeModeLabel(theme.platform)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.light_mode_outlined),
                            title: const Text('Light'),
                            onTap: () => Navigator.pop(ctx),
                          ),
                          ListTile(
                            leading: const Icon(Icons.dark_mode_outlined),
                            title: const Text('Dark'),
                            onTap: () => Navigator.pop(ctx),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings_brightness_outlined),
                            title: const Text('System'),
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const _SectionHeader(title: 'Data'),

          FadeSlideIn(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Column(
                children: [
                  HoverCard(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('Accounts'),
                      subtitle: const Text('Create / edit your cash, checking, credit...'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AccountsPage()),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  HoverCard(
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('DB Debug'),
                      subtitle: const Text('Test Drift CRUD (temporary)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DbDebugPage()),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
                    title: Text('Delete all data', style: TextStyle(color: Colors.red.shade700)),
                    subtitle: const Text('Permanently remove everything'),
                    onTap: () => _deleteAllData(context, ref),
                  ),
                ],
              ),
            ),
          ),

          const _SectionHeader(title: 'About'),

          FadeSlideIn(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              child: const Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('PocketPulse'),
                    subtitle: Text('Version 0.1.0 \u2022 Build 1'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _lastingSubtitle(String reminderLabel) {
    return 'On \u2014 upcoming recurring items will be scheduled at $reminderLabel.';
  }

  String _themeModeLabel(TargetPlatform platform) {
    return 'System default';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
