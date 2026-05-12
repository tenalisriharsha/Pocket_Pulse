import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared formatting utilities for PocketPulse.
/// All methods are pure (no side effects) and can be used in build methods.

class Formatters {
  Formatters._();

  static final _monthFmt = DateFormat('yyyy-MM');
  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _moneyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  /// Formats an ISO month key like "2024-06".
  static String monthKey(DateTime d) => _monthFmt.format(d);

  /// Formats a date as "yyyy-MM-dd".
  static String date(DateTime d) => _dateFmt.format(d);

  /// Formats cents into "\$XX.YY" (always with sign prefix).
  static String money(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final dollars = abs ~/ 100;
    final c = (abs % 100).toString().padLeft(2, '0');
    return '$sign\$$dollars.$c';
  }

  /// Formats money using intl (locale-aware). Slightly slower; avoid in tight loops.
  static String moneyIntl(int cents) => _moneyFmt.format(cents / 100.0);

  /// Short month label like "Jun 2024".
  static String monthLabel(DateTime d) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  /// Returns start of day (midnight).
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Returns end of day (23:59:59).
  static DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
}

/// Extension on [BuildContext] for quick theme access.
extension ThemeX on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
