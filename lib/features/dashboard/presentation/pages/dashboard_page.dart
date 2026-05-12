import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/animations/animated_counter.dart';
import '../../../../shared/animations/fade_slide_in.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../../data/local_db/app_database.dart';
import '../../../../shared/utils/category_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/money_text.dart';
import '../../../../shared/widgets/month_selector.dart';
import '../../../../shared/widgets/unified_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);


  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _goToReports({String? categoryFilter}) {
    if (categoryFilter != null) {
      context.go('/reports');
    } else {
      context.go('/reports');
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final monthKey = Formatters.monthKey(_month);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('This month at a glance',
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    MonthSelector(
                      month: _month,
                      onChanged: (d) => setState(() => _month = d),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => _QuickActionsSheet(
                            onReports: () => _goToReports(),
                            onSettings: () => context.go('/settings'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Summary strip ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FadeSlideIn(
                  child: _SummaryStrip(
                    db: db,
                    monthKey: monthKey,
                    onTap: () => _goToReports(),
                  ),
                ),
              ),
            ),

            // ── Primary insights: Donut ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: StreamBuilder<List<CategorySpendRow>> (
                    stream: db.reportsDao.watchSpendByCategory(monthKey, type: 'expense'),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final rows = snap.data!;
                      if (rows.isEmpty) {
                        return UnifiedCard(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No expenses yet. Add a few transactions to see insights.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ),
                        );
                      }
                      final total = rows.fold<int>(0, (s, r) => s + r.spentCents);
                      final top = rows.first;
                      return _DonutInsightCard(
                        rows: rows,
                        total: total,
                        topCategoryName: top.categoryName,
                        topCategoryId: top.categoryId,
                        onSliceTap: (catId) => _goToReports(categoryFilter: '$catId'),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── Secondary insights: Top merchants ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: StreamBuilder<List<MerchantSpendRow>>(
                    stream: db.reportsDao.watchTopMerchantsByType(
                      monthKey,
                      type: 'expense',
                      limit: 5,
                    ),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final rows = snap.data!;
                      if (rows.isEmpty) return const SizedBox.shrink();
                      return _MerchantsCard(
                        rows: rows,
                        onSeeAll: () => _goToReports(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Summary Strip
// ═════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  final dynamic db;
  final String monthKey;
  final VoidCallback onTap;

  const _SummaryStrip({required this.db, required this.monthKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<MonthSummary>(
      stream: db.reportsDao.watchMonthSummary(monthKey),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const UnifiedCard(
            child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
          );
        }

        final s = snap.data!;
        return UnifiedCard(
          onTap: onTap,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCol(
                      label: 'Income',
                      valueCents: s.incomeCents,
                      color: Colors.green.shade700,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  Container(width: 1, height: 50, color: cs.outlineVariant),
                  Expanded(
                    child: _SummaryCol(
                      label: 'Spend',
                      valueCents: s.expenseCents,
                      color: Colors.red.shade700,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  Container(width: 1, height: 50, color: cs.outlineVariant),
                  Expanded(
                    child: _SummaryCol(
                      label: 'Net',
                      valueCents: s.netCents,
                      color: s.netCents >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      icon: Icons.balance,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TrendChip(label: 'Income', cents: s.incomeCents),
                  _TrendChip(label: 'Spend', cents: s.expenseCents),
                  _TrendChip(label: 'Net', cents: s.netCents),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final int valueCents;
  final Color color;
  final IconData icon;

  const _SummaryCol({
    required this.label,
    required this.valueCents,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedCounter(
          target: valueCents,
          formatter: Formatters.money,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final int cents;

  const _TrendChip({required this.label, required this.cents});

  @override
  Widget build(BuildContext context) {
    // Placeholder trend: always show "vs last month" neutral for now
    return Text(
      'vs last month',
      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Donut Insight Card
// ═════════════════════════════════════════════════════════════════

class _DonutInsightCard extends StatelessWidget {
  final List<dynamic> rows;
  final int total;
  final String topCategoryName;
  final int topCategoryId;
  final ValueChanged<int> onSliceTap;

  const _DonutInsightCard({
    required this.rows,
    required this.total,
    required this.topCategoryName,
    required this.topCategoryId,
    required this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spend by category',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: _DonutMini(
                  items: rows,
                  total: total,
                  onSliceTap: onSliceTap,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total spend',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    MoneyText(cents: total, fontSize: 26),
                    const SizedBox(height: 12),
                    Text('Top category',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: CategoryColors.forIndex(0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(topCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < rows.length && i < 6; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: CategoryColors.forIndex(i),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rows[i].categoryName} ${((rows[i].spentCents / total) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutMini extends StatefulWidget {
  final List<dynamic> items;
  final int total;
  final ValueChanged<int> onSliceTap;

  const _DonutMini({
    required this.items,
    required this.total,
    required this.onSliceTap,
  });

  @override
  State<_DonutMini> createState() => _DonutMiniState();
}

class _DonutMiniState extends State<_DonutMini>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) {
            final idx = _hitTest(d.localPosition, size);
            if (idx == null) return;
            widget.onSliceTap(widget.items[idx].categoryId as int);
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _MiniDonutPainter(
                  items: widget.items,
                  total: widget.total,
                  progress: _controller.value,
                ),
              );
            },
          ),
        );
      },
    );
  }

  int? _hitTest(Offset local, Size size) {
    if (widget.total <= 0 || widget.items.isEmpty) return null;
    final center = size.center(Offset.zero);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.32;
    if (dist < radius - stroke || dist > radius) return null;
    var ang = math.atan2(dy, dx);
    const startAngle = -math.pi / 2;
    ang = ang - startAngle;
    while (ang < 0) ang += (2 * math.pi);
    while (ang >= 2 * math.pi) ang -= (2 * math.pi);
    var acc = 0.0;
    for (var i = 0; i < widget.items.length; i++) {
      final v = widget.items[i].spentCents as int;
      if (v <= 0) continue;
      final sweep = (v / widget.total) * (2 * math.pi);
      if (ang >= acc && ang < acc + sweep) return i;
      acc += sweep;
    }
    return null;
  }
}

class _MiniDonutPainter extends CustomPainter {
  final List<dynamic> items;
  final int total;
  final double progress;

  _MiniDonutPainter({required this.items, required this.total, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.32;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius - stroke / 2, bgPaint);

    if (total <= 0) return;

    var start = -math.pi / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < items.length; i++) {
      final value = (items[i].spentCents as int);
      if (value <= 0) continue;
      final sweep = (value / total) * (2 * math.pi) * progress;
      ringPaint.color = CategoryColors.forIndex(i);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        sweep,
        false,
        ringPaint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDonutPainter old) {
    return old.total != total || old.items.length != items.length || old.progress != progress;
  }
}

// ═════════════════════════════════════════════════════════════════
// Merchants Card
// ═════════════════════════════════════════════════════════════════

class _MerchantsCard extends StatelessWidget {
  final List<dynamic> rows;
  final VoidCallback onSeeAll;

  const _MerchantsCard({required this.rows, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top merchants',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  MoneyText(
                    cents: rows[i].spentCents,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Quick Actions Bottom Sheet
// ═════════════════════════════════════════════════════════════════

class _QuickActionsSheet extends StatelessWidget {
  final VoidCallback onReports;
  final VoidCallback onSettings;

  const _QuickActionsSheet({required this.onReports, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Go to Reports'),
              onTap: () {
                Navigator.pop(context);
                onReports();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                onSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
