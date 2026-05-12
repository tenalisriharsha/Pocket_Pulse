import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local_db/app_database.dart';
import '../../../../data/repositories/providers.dart';
import '../../../../features/transactions/presentation/providers/transaction_providers.dart';
import '../../../../shared/animations/animated_counter.dart';
import '../../../../shared/animations/app_animations.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/hover_card.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../../../shared/utils/category_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/money_text.dart';
import '../../../../shared/widgets/month_selector.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime _month;
  int? _selectedAccountId;
  int? _selectedCategoryId;
  String _flowType = 'expense';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final monthKey = Formatters.monthKey(_month);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];

    final selectedCat = _selectedCategoryId == null
        ? null
        : categories.cast<Category?>().firstWhere(
              (c) => c?.id == _selectedCategoryId,
              orElse: () => null,
            );

    if (selectedCat != null && selectedCat.type.toLowerCase() != _flowType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCategoryId = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          MonthSelector(
            month: _month,
            onChanged: (d) => setState(() => _month = d),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Filters ──
          FadeSlideIn(
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All accounts')),
                              for (final a in accounts)
                                DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                            ],
                            onChanged: (v) => setState(() => _selectedAccountId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                              for (final c in categories)
                                DropdownMenuItem<int?>(value: c.id, child: Text('${c.name} (${c.type})')),
                            ],
                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'expense', label: Text('Expense')),
                        ButtonSegment(value: 'income', label: Text('Income')),
                      ],
                      selected: {_flowType},
                      onSelectionChanged: (s) => setState(() => _flowType = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showing: ${Formatters.monthLabel(_month)}'
                      '${_selectedAccountId == null ? '' : ' \u2022 account filtered'}'
                      '${_selectedCategoryId == null ? '' : ' \u2022 category filtered'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Summary ──
          StreamBuilder<MonthSummary>(
            stream: db.reportsDao.watchMonthSummary(
              monthKey,
              accountId: _selectedAccountId,
              categoryId: _selectedCategoryId,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final s = snap.data!;
              return Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 50),
                      child: _SummaryMini(
                        title: 'Income',
                        cents: s.incomeCents,
                        icon: Icons.arrow_downward,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: _SummaryMini(
                        title: 'Spend',
                        cents: s.expenseCents,
                        icon: Icons.arrow_upward,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: _SummaryMini(
                        title: 'Net',
                        cents: s.netCents,
                        icon: Icons.balance,
                        color: s.netCents >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Trend ──
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: Text('Trend (last 6 months)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<TrendPoint>>(
            stream: db.reportsDao.watchTrendByType(
              monthKey: monthKey,
              type: _flowType,
              monthsBack: 6,
              accountId: _selectedAccountId,
              categoryId: _selectedCategoryId,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final points = snap.data!;
              final maxVal = points.fold<int>(0, (m, p) => math.max(m, p.expenseCents));
              final label = _flowType == 'expense' ? 'Expense' : 'Income';
              final subtitle = _selectedCategoryId == null
                  ? 'Total $label trend'
                  : 'Filtered category trend ($label)';

              return FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: RepaintBoundary(
                            child: _LineTrendChart(
                              points: points,
                              maxY: maxVal,
                              lineColor: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(points.isNotEmpty ? points.first.monthKey : '',
                                style: theme.textTheme.bodySmall),
                            Text(points.isNotEmpty ? points.last.monthKey : '',
                                style: theme.textTheme.bodySmall),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Spend by category ──
          FadeSlideIn(
            delay: const Duration(milliseconds: 260),
            child: Text(
              _flowType == 'expense' ? 'Spend by category' : 'Income by category',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<CategorySpendRow>>(
            stream: db.reportsDao.watchSpendByCategory(
              monthKey,
              type: _flowType,
              accountId: _selectedAccountId,
              categoryId: _selectedCategoryId,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final rows = snap.data!;
              if (rows.isEmpty) {
                return FadeSlideIn(
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No ${_flowType == 'expense' ? 'expense' : 'income'} data for this month (with current filters).',
                      ),
                    ),
                  ),
                );
              }

              final total = rows.fold<int>(0, (a, r) => a + r.spentCents);

              return Column(
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: RepaintBoundary(
                                    child: _DonutChart(
                                      items: rows,
                                      total: total,
                                      onSliceTap: (categoryId) {
                                        setState(() => _selectedCategoryId = categoryId);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _flowType == 'income' ? 'Total income' : 'Total spend',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 6),
                                      MoneyText(cents: total, fontSize: 28, fontWeight: FontWeight.w700),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tap a slice to filter by category.',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _DonutLegend(items: rows, total: total),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 340),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length && i < 12; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            HoverCard(
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: CategoryColors.forIndex(i).withValues(alpha: 0.2),
                                  child: Icon(Icons.label_outline, size: 12, color: CategoryColors.forIndex(i)),
                                ),
                                title: Text(rows[i].categoryName),
                                subtitle: total == 0
                                    ? null
                                    : Text('${((rows[i].spentCents / total) * 100).toStringAsFixed(1)}%'),
                                trailing: MoneyText(
                                  cents: rows[i].spentCents,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Top merchants ──
          FadeSlideIn(
            delay: const Duration(milliseconds: 380),
            child: Text('Top merchants',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<MerchantSpendRow>>(
            stream: db.reportsDao.watchTopMerchantsByType(
              monthKey,
              type: _flowType,
              limit: 7,
              accountId: _selectedAccountId,
              categoryId: _selectedCategoryId,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final rows = snap.data!;
              if (rows.isEmpty) {
                return FadeSlideIn(
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No merchant spending for this month (with current filters).'),
                    ),
                  ),
                );
              }

              return FadeSlideIn(
                delay: const Duration(milliseconds: 420),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        HoverCard(
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: cs.surfaceContainerHighest,
                              child: Text('${i + 1}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                            ),
                            title: Text(rows[i].merchant),
                            trailing: MoneyText(
                              cents: rows[i].spentCents,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  final String title;
  final int cents;
  final IconData icon;
  final Color color;

  const _SummaryMini({
    required this.title,
    required this.cents,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            MoneyText(cents: cents, fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ],
        ),
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final List<dynamic> items;
  final int total;

  const _DonutLegend({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length && i < 10; i++)
          _LegendItem(
            color: CategoryColors.forIndex(i),
            label: items[i].categoryName as String,
            pct: total == 0 ? 0 : (items[i].spentCents as int) / total,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${(pct * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DonutChart extends StatefulWidget {
  final List<dynamic> items;
  final int total;
  final void Function(int categoryId)? onSliceTap;

  const _DonutChart({
    required this.items,
    required this.total,
    this.onSliceTap,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimationDurations.slow,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _DonutChart old) {
    super.didUpdateWidget(old);
    if (old.total != widget.total || old.items.length != widget.items.length) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _hitTestSlice(Offset local, Size size) {
    if (widget.total <= 0 || widget.items.isEmpty) return null;
    final center = size.center(Offset.zero);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.35;
    final innerR = radius - stroke;
    final outerR = radius;
    if (dist < innerR || dist > outerR) return null;
    var ang = math.atan2(dy, dx);
    const startAngle = -math.pi / 2;
    ang = ang - startAngle;
    while (ang < 0) {
      ang += (2 * math.pi);
    }
    while (ang >= 2 * math.pi) {
      ang -= (2 * math.pi);
    }
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) {
            if (widget.onSliceTap == null) return;
            final idx = _hitTestSlice(d.localPosition, size);
            if (idx == null) return;
            final catId = widget.items[idx].categoryId as int;
            widget.onSliceTap!(catId);
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _DonutPainter(
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
}

class _DonutPainter extends CustomPainter {
  final List<dynamic> items;
  final int total;
  final double progress;

  _DonutPainter({required this.items, required this.total, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.35;

    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius - stroke / 2, bgPaint);
    if (total <= 0) return;

    var start = -math.pi / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < items.length; i++) {
      final row = items[i];
      final value = (row.spentCents as int);
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

    final textSpan = TextSpan(
      text: (total / 100).toStringAsFixed(0),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.total != total || old.items.length != items.length || old.progress != progress;
  }
}

class _LineTrendChart extends StatefulWidget {
  final List<dynamic> points;
  final int maxY;
  final Color lineColor;

  const _LineTrendChart({
    required this.points,
    required this.maxY,
    required this.lineColor,
  });

  @override
  State<_LineTrendChart> createState() => _LineTrendChartState();
}

class _LineTrendChartState extends State<_LineTrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimationDurations.slow,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _LineTrendChart old) {
    super.didUpdateWidget(old);
    if (old.points.length != widget.points.length || old.maxY != widget.maxY) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LineTrendPainter(
            points: widget.points,
            maxY: widget.maxY,
            lineColor: widget.lineColor,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _LineTrendPainter extends CustomPainter {
  final List<dynamic> points;
  final int maxY;
  final Color lineColor;
  final double progress;

  _LineTrendPainter({
    required this.points,
    required this.maxY,
    required this.lineColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 14.0;
    final w = size.width;
    final h = size.height;
    final plotLeft = padding;
    final plotTop = padding;
    final plotRight = w - padding;
    final plotBottom = h - padding;

    final axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
        Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom), axisPaint);
    canvas.drawLine(
        Offset(plotLeft, plotTop), Offset(plotLeft, plotBottom), axisPaint);

    if (points.isEmpty) return;

    final n = points.length;
    final safeMax = math.max(maxY, 1);
    final visiblePoints = (n * progress).ceil().clamp(1, n);

    double xFor(int i) {
      if (n == 1) return (plotLeft + plotRight) / 2;
      final t = i / (n - 1);
      return plotLeft + (plotRight - plotLeft) * t;
    }

    double yFor(int cents) {
      final t = cents / safeMax;
      return plotBottom - (plotBottom - plotTop) * t;
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < visiblePoints; i++) {
      final p = points[i];
      final y = yFor(p.expenseCents as int);
      final x = xFor(i);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < visiblePoints; i++) {
      final p = points[i];
      canvas.drawCircle(Offset(xFor(i), yFor(p.expenseCents as int)), 3.2, dotPaint);
    }

    final label = '\$${(safeMax / 100).toStringAsFixed(0)}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(plotLeft + 4, plotTop - 10));
  }

  @override
  bool shouldRepaint(covariant _LineTrendPainter old) {
    return old.maxY != maxY ||
        old.lineColor != lineColor ||
        old.points.length != points.length ||
        old.progress != progress;
  }
}
