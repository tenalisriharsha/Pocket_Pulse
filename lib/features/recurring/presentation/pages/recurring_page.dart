import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:pocket_pulse/shared/animations/confetti_overlay.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/hover_card.dart';
import 'package:pocket_pulse/shared/animations/pulse.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/services/notification_service.dart';
import 'package:pocket_pulse/shared/providers/reminder_time_provider.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';
import 'package:pocket_pulse/shared/widgets/money_text.dart';

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  int _daysAhead = 30;

  bool _notifPermissionChecked = false;
  bool _notifAllowed = false;

  String? _lastNotifSyncSignature;
  bool _cancelledBecauseDisabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final enabled = ref.read(remindersEnabledProvider).valueOrNull ?? false;
      if (enabled) await _ensureNotificationPermission();
    });
  }

  String _fmtMoney(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final c = (abs % 100).toString().padLeft(2, '0');
    return '$sign\$$dollars.$c';
  }

  Future<void> _ensureNotificationPermission({bool forcePrompt = false}) async {
    if (_notifPermissionChecked && !forcePrompt) return;
    _notifPermissionChecked = true;
    final ok = await NotificationService.instance.requestPermissions();
    if (!mounted) return;
    setState(() => _notifAllowed = ok);
    if (!ok && forcePrompt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are disabled. Enable in macOS System Settings \u2192 Notifications.',
          ),
        ),
      );
    }
  }

  int _timeToMinutes(TimeOfDay t) => (t.hour * 60) + t.minute;

  void _syncNotificationsIfNeeded({
    required List<RecurringRow> rows,
    required TimeOfDay reminderTime,
    required bool remindersEnabled,
  }) {
    if (!remindersEnabled) {
      if (!_cancelledBecauseDisabled) {
        _cancelledBecauseDisabled = true;
        _lastNotifSyncSignature = null;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await NotificationService.instance.cancelAll();
        });
      }
      return;
    }
    if (!_notifAllowed) return;
    _cancelledBecauseDisabled = false;

    final sig = StringBuffer('days=$_daysAhead|rt=${_timeToMinutes(reminderTime)}|');
    for (final r in rows) {
      final rule = r.rule;
      sig.write('${rule.id}:${rule.nextDueDate.millisecondsSinceEpoch}:${rule.isActive}|');
    }
    final signature = sig.toString();
    if (signature == _lastNotifSyncSignature) return;
    _lastNotifSyncSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final upcoming = rows
          .where((r) => r.rule.isActive)
          .map((r) => (id: r.rule.id, name: r.rule.name, nextDueDate: r.rule.nextDueDate))
          .toList();
      await NotificationService.instance.syncUpcomingRules(
        rules: upcoming,
        daysAhead: _daysAhead,
        reminderTime: reminderTime,
      );
    });
  }

  Future<void> _openEditor({
    required AppDatabase db,
    RecurringRule? existing,
  }) async {
    final accounts = await db.accountsDao.getAll();
    final categories = await db.categoriesDao.getAll();
    if (!mounted) return;

    String type = (existing?.type ?? 'expense').toLowerCase();
    int amountCents = existing?.amountCents ?? 0;
    int accountId = existing?.accountId ?? (accounts.isNotEmpty ? accounts.first.id : 1);
    int? categoryId = existing?.categoryId;
    String frequency = (existing?.frequency ?? 'monthly').toLowerCase();
    int interval = existing?.interval ?? 1;
    DateTime nextDue = existing?.nextDueDate ?? DateTime.now();
    bool isActive = existing?.isActive ?? true;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: (amountCents.abs() / 100).toStringAsFixed(2),
    );
    final intervalCtrl = TextEditingController(text: interval.toString());
    final moneyFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final filteredCats = categories
                .where((c) => c.type.toLowerCase() == type)
                .toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (categoryId != null && !filteredCats.any((c) => c.id == categoryId)) {
              categoryId = null;
            }
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(existing == null ? 'Add recurring' : 'Edit recurring',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (e.g., Netflix)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'expense', label: Text('Expense')),
                                ButtonSegment(value: 'income', label: Text('Income')),
                              ],
                              selected: {type},
                              onSelectionChanged: (s) => setLocal(() => type = s.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [moneyFormatter],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: accountId,
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          border: OutlineInputBorder(),
                        ),
                        items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                        onChanged: (v) => setLocal(() => accountId = v ?? accountId),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('None')),
                          for (final c in filteredCats)
                            DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setLocal(() => categoryId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                              ],
                              onChanged: (v) => setLocal(() => frequency = (v ?? 'monthly')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: intervalCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Every',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Next due: ${Formatters.date(nextDue)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: nextDue,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked == null) return;
                          setLocal(() => nextDue = DateTime(picked.year, picked.month, picked.day));
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setLocal(() => isActive = v),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    final amt = double.tryParse(amountCtrl.text.trim());
    final parsedInterval = int.tryParse(intervalCtrl.text.trim()) ?? interval;
    nameCtrl.dispose();
    amountCtrl.dispose();
    intervalCtrl.dispose();
    if (ok != true) return;
    if (name.isEmpty || amt == null || amt < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and amount')),
      );
      return;
    }

    interval = parsedInterval <= 0 ? 1 : parsedInterval;
    amountCents = (amt * 100).round();

    if (existing == null) {
      await db.recurringRulesDao.insertRule(
        RecurringRulesCompanion.insert(
          name: name,
          amountCents: amountCents,
          type: type,
          accountId: accountId,
          categoryId: categoryId == null ? const Value.absent() : Value(categoryId!),
          frequency: frequency,
          interval: Value(interval),
          nextDueDate: nextDue,
          isActive: const Value(true),
        ),
      );
    } else {
      await db.recurringRulesDao.updateRule(
        existing.copyWith(
          name: name,
          amountCents: amountCents,
          type: type,
          accountId: accountId,
          categoryId: Value(categoryId),
          frequency: frequency,
          interval: interval,
          nextDueDate: nextDue,
          isActive: isActive,
        ),
      );
    }

    _lastNotifSyncSignature = null;
    final enabled = ref.read(remindersEnabledProvider).valueOrNull ?? false;
    if (enabled) await _ensureNotificationPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recurring rule saved')),
    );
  }

  Future<bool> _confirmMarkPaid(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text('This will record the payment and advance the next due date.\n\n$name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark paid')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final remindersEnabled = ref.watch(remindersEnabledProvider).valueOrNull ?? false;
    final reminderTime = ref.watch(reminderTimeProvider).valueOrNull ??
        const TimeOfDay(hour: 9, minute: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            tooltip: _notifAllowed ? 'Notifications allowed' : 'Request notification permission',
            icon: Icon(_notifAllowed
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined),
            onPressed: () => _ensureNotificationPermission(forcePrompt: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 14, label: Text('14d')),
                ButtonSegment(value: 30, label: Text('30d')),
              ],
              selected: {_daysAhead},
              onSelectionChanged: (s) {
                setState(() {
                  _daysAhead = s.first;
                  _lastNotifSyncSignature = null;
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add recurring',
        onPressed: () => _openEditor(db: db),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RecurringRow>>(
        stream: db.recurringRulesDao.watchUpcoming(daysAhead: _daysAhead),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recurring stream error:\n${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final rows = snap.data!;
          _syncNotificationsIfNeeded(
            rows: rows,
            reminderTime: reminderTime,
            remindersEnabled: remindersEnabled,
          );

          if (rows.isEmpty) {
            return FadeSlideIn(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.autorenew, size: 48, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No upcoming recurring items\nin the next $_daysAhead days',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text('Tap + to add one', style: TextStyle(color: cs.outline, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final overdue = rows.where((r) => r.rule.nextDueDate.isBefore(today)).toList();
          final dueSoon = rows.where((r) {
            final d = r.rule.nextDueDate;
            return !d.isBefore(today) && d.difference(today).inDays <= 7;
          }).toList();
          final later = rows.where((r) {
            final d = r.rule.nextDueDate;
            return !d.isBefore(today) && d.difference(today).inDays > 7;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue.isNotEmpty) ...[
                _SectionTitle(title: 'Overdue', color: Colors.red.shade700),
                const SizedBox(height: 8),
                ...overdue.map((r) => _RecurringTile(
                  row: r,
                  db: db,
                  onMarkPaid: () async {
                    final ok = await _confirmMarkPaid(r.rule.name);
                    if (!ok) return;
                    await db.recurringRulesDao.markAsPaid(r.rule.id, createTransaction: true);
                    _lastNotifSyncSignature = null;
                    if (!mounted) return;
                    ConfettiHelper.burst(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked paid + advanced due date')),
                    );
                  },
                  onEdit: () => _openEditor(db: db, existing: r.rule),
                )),
                const SizedBox(height: 16),
              ],
              if (dueSoon.isNotEmpty) ...[
                _SectionTitle(title: 'Due soon', color: Colors.orange.shade700),
                const SizedBox(height: 8),
                ...dueSoon.map((r) => _RecurringTile(
                  row: r,
                  db: db,
                  onMarkPaid: () async {
                    final ok = await _confirmMarkPaid(r.rule.name);
                    if (!ok) return;
                    await db.recurringRulesDao.markAsPaid(r.rule.id, createTransaction: true);
                    _lastNotifSyncSignature = null;
                    if (!mounted) return;
                    ConfettiHelper.burst(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked paid + advanced due date')),
                    );
                  },
                  onEdit: () => _openEditor(db: db, existing: r.rule),
                )),
                const SizedBox(height: 16),
              ],
              if (later.isNotEmpty) ...[
                _SectionTitle(title: 'Later', color: cs.onSurfaceVariant),
                const SizedBox(height: 8),
                ...later.map((r) => _RecurringTile(
                  row: r,
                  db: db,
                  onMarkPaid: () async {
                    final ok = await _confirmMarkPaid(r.rule.name);
                    if (!ok) return;
                    await db.recurringRulesDao.markAsPaid(r.rule.id, createTransaction: true);
                    _lastNotifSyncSignature = null;
                    if (!mounted) return;
                    ConfettiHelper.burst(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked paid + advanced due date')),
                    );
                  },
                  onEdit: () => _openEditor(db: db, existing: r.rule),
                )),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringRow row;
  final AppDatabase db;
  final VoidCallback onMarkPaid;
  final VoidCallback onEdit;

  const _RecurringTile({
    required this.row,
    required this.db,
    required this.onMarkPaid,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rule = row.rule;
    final isExpense = rule.type.toLowerCase() == 'expense';
    final signed = isExpense ? -rule.amountCents.abs() : rule.amountCents.abs();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = rule.nextDueDate.isBefore(today);

    Widget card = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: overdue
          ? Colors.red.shade50.withValues(alpha: 0.6)
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: overdue ? Colors.red.shade100 : cs.primaryContainer,
          child: Icon(
            overdue ? Icons.warning_amber_rounded : Icons.autorenew,
            size: 18,
            color: overdue ? Colors.red.shade700 : cs.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.name,
                style: TextStyle(
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _StatusPill(active: rule.isActive),
          ],
        ),
        subtitle: Text(
          '${row.account.name} \u2022 ${row.category?.name ?? 'No category'}\nDue ${Formatters.date(rule.nextDueDate)} \u2022 Every ${rule.interval} ${rule.frequency}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: MoneyText(
          cents: signed,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
        ),
        onTap: onEdit,
      ),
    );

    if (overdue) {
      card = Pulse(child: card);
    }

    return FadeSlideIn(
      child: HoverCard(child: card),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;

  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green.shade700 : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Enabled' : 'Off',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
