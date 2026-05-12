import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocket_pulse/shared/animations/app_animations.dart';
import 'package:pocket_pulse/shared/animations/confetti_overlay.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/hover_card.dart';
import 'package:pocket_pulse/shared/animations/pulse.dart';
import 'package:pocket_pulse/shared/animations/shake.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';
import 'package:pocket_pulse/shared/widgets/money_text.dart';
import 'package:pocket_pulse/shared/widgets/month_selector.dart';

class BudgetsPage extends ConsumerStatefulWidget {
  const BudgetsPage({super.key});

  @override
  ConsumerState<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends ConsumerState<BudgetsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final Set<String> _sessionAlertsFired = {};
  bool _rolloverEnabled = false;
  bool _rolloverOnlyPositive = true;

  String get _monthKey => Formatters.monthKey(_month);

  Future<void> _copyPreviousMonth(AppDatabase db) async {
    await db.budgetsDao.copyFromPreviousMonth(_monthKey);
    if (!mounted) return;
    ConfettiHelper.burst(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied previous month budgets')),
    );
  }

  Future<void> _editBudget({
    required AppDatabase db,
    required int categoryId,
    required String categoryName,
    required int currentBudgetCents,
  }) async {
    final ctrl = TextEditingController(
      text: currentBudgetCents == 0 ? '' : (currentBudgetCents / 100).toStringAsFixed(2),
    );
    final moneyInputFormatter = FilteringTextInputFormatter.allow(
      RegExp(r'^\d*\.?\d{0,2}$'),
    );

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Set budget: $categoryName',
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [moneyInputFormatter],
                decoration: const InputDecoration(
                  labelText: 'Monthly budget',
                  prefixText: '\$ ',
                  helperText: 'Set to 0 to disable',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 0),
                      child: const Text('Set to 0'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final val = double.tryParse(ctrl.text.trim());
                        if (val == null || val < 0) {
                          Navigator.pop(ctx, null);
                          return;
                        }
                        Navigator.pop(ctx, (val * 100).round());
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    ctrl.dispose();
    if (result == null) return;

    await db.budgetsDao.setBudget(
      monthKey: _monthKey,
      categoryId: categoryId,
      amountCents: result,
    );

    if (!mounted) return;
    ConfettiHelper.burst(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budget saved')),
    );
  }

  void _maybeFireAlerts({
    required AppDatabase db,
    required List<BudgetCategorySummary> rows,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      for (final r in rows) {
        if (r.budgetCents <= 0) continue;
        final pct = r.pctUsed;
        final key80 = '$_monthKey:${r.categoryId}:80';
        final key100 = '$_monthKey:${r.categoryId}:100';

        if (pct >= 1.0 && !r.alert100Sent && !_sessionAlertsFired.contains(key100)) {
          _sessionAlertsFired.add(key100);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${r.categoryName}: budget reached (100%)'),
              backgroundColor: Colors.red.shade700,
            ),
          );
          await db.budgetsDao.markAlertSent(
            monthKey: _monthKey,
            categoryId: r.categoryId,
            level: 100,
          );
          continue;
        }

        if (pct >= 0.8 && pct < 1.0 && !r.alert80Sent && !r.alert100Sent && !_sessionAlertsFired.contains(key80)) {
          _sessionAlertsFired.add(key80);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${r.categoryName}: 80% of budget used'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          await db.budgetsDao.markAlertSent(
            monthKey: _monthKey,
            categoryId: r.categoryId,
            level: 80,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          MonthSelector(
            month: _month,
            onChanged: (d) => setState(() {
              _month = d;
              _sessionAlertsFired.clear();
            }),
          ),
          IconButton(
            tooltip: 'Copy previous month',
            onPressed: () => _copyPreviousMonth(db),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Budget options',
            onSelected: (value) {
              setState(() {
                if (value == 'toggle_rollover') {
                  _rolloverEnabled = !_rolloverEnabled;
                } else if (value == 'toggle_only_positive') {
                  _rolloverOnlyPositive = !_rolloverOnlyPositive;
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'toggle_rollover',
                checked: _rolloverEnabled,
                child: const Text('Rollover remaining'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'toggle_only_positive',
                enabled: _rolloverEnabled,
                checked: _rolloverOnlyPositive,
                child: const Text('Only positive rollover'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: StreamBuilder<List<BudgetCategorySummary>>(
        stream: db.budgetsDao.watchMonthCategorySummary(
          _monthKey,
          rollover: _rolloverEnabled,
          rolloverOnlyPositive: _rolloverOnlyPositive,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Budgets stream error:\n${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No expense categories found.'));
          }

          _maybeFireAlerts(db: db, rows: rows);

          final totalBudget = rows.fold<int>(0, (s, r) => s + r.budgetCents);
          final totalSpent = rows.fold<int>(0, (s, r) => s + r.spentCents);
          final totalRemaining = totalBudget - totalSpent;
          final overallPct = totalBudget == 0 ? 0.0 : (totalSpent / totalBudget).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Compact header ──
              FadeSlideIn(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _HeaderCol(
                                label: 'Budgeted',
                                cents: totalBudget,
                                color: cs.onSurface,
                              ),
                            ),
                            Expanded(
                              child: _HeaderCol(
                                label: 'Spent',
                                cents: totalSpent,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Expanded(
                              child: _HeaderCol(
                                label: 'Remaining',
                                cents: totalRemaining,
                                color: totalRemaining >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: overallPct,
                            minHeight: 10,
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              overallPct >= 1.0
                                  ? Colors.red.shade600
                                  : overallPct >= 0.8
                                      ? Colors.orange.shade600
                                      : Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Text('By category',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),

              for (var i = 0; i < rows.length; i++) ...[
                FadeSlideIn(
                  delay: Duration(milliseconds: 100 + i * 40),
                  child: _BudgetCard(
                    row: rows[i],
                    onTap: () => _editBudget(
                      db: db,
                      categoryId: rows[i].categoryId,
                      categoryName: rows[i].categoryName,
                      currentBudgetCents: rows[i].budgetCents,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCol extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;

  const _HeaderCol({required this.label, required this.cents, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        MoneyText(
          cents: cents,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ],
    );
  }
}

class _BudgetCard extends StatefulWidget {
  final BudgetCategorySummary row;
  final VoidCallback onTap;

  const _BudgetCard({required this.row, required this.onTap});

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: AppAnimationDurations.slow,
    );
    _progressController.forward();
  }

  @override
  void didUpdateWidget(covariant _BudgetCard old) {
    super.didUpdateWidget(old);
    if (old.row.pctUsed != widget.row.pctUsed) {
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Color _progressColor(double pct) {
    if (pct >= 1.0) return Colors.red.shade600;
    if (pct >= 0.8) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = widget.row;

    final animatedProgress = Tween<double>(
      begin: 0,
      end: r.budgetCents == 0 ? 0 : r.pctUsed.clamp(0, 1),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: AppAnimationCurves.standard,
    ));

    Widget card = InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.categoryName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.pctUsed >= 1.0)
                    _WarningChip(
                      text: 'Over budget',
                      color: Colors.red.shade700,
                      icon: Icons.warning_amber_rounded,
                    )
                  else if (r.pctUsed >= 0.8)
                    _WarningChip(
                      text: '80% used',
                      color: Colors.orange.shade700,
                      icon: Icons.info_outline,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: animatedProgress.value,
                      minHeight: 10,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(_progressColor(r.pctUsed)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BudgetMeta(label: 'Budget', cents: r.budgetCents),
                  _BudgetMeta(label: 'Spent', cents: r.spentCents),
                  _BudgetMeta(
                    label: 'Left',
                    cents: r.remainingCents,
                    valueColor: r.remainingCents >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (r.pctUsed >= 1.0) {
      card = Shake(shake: true, child: card);
    }
    return HoverCard(child: card);
  }
}

class _WarningChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _WarningChip({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _BudgetMeta extends StatelessWidget {
  final String label;
  final int cents;
  final Color? valueColor;

  const _BudgetMeta({required this.label, required this.cents, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 2),
        MoneyText(
          cents: cents,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: valueColor,
        ),
      ],
    );
  }
}
