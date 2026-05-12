import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// A compact month picker chip used in app bars across the app.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final String? label;

  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
    this.label,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: label ?? 'Select month',
    );
    if (picked == null) return;
    onChanged(DateTime(picked.year, picked.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(Icons.calendar_today_outlined, size: 16, color: cs.primary),
      label: Text(Formatters.monthLabel(month)),
      side: BorderSide(color: cs.outlineVariant),
      backgroundColor: cs.surface,
      onPressed: () => _pick(context),
    );
  }
}
