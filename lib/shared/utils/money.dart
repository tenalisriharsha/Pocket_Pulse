import 'package:intl/intl.dart';

class Money {
  static String formatCents(
    int cents, {
    String currency = 'USD',
  }) {
    final amount = cents / 100.0;
    final fmt = NumberFormat.simpleCurrency(name: currency);
    return fmt.format(amount);
  }

  static String formatSignedCents(
    int cents, {
    String currency = 'USD',
  }) {
    // simpleCurrency already formats negatives like -$12.34
    return formatCents(cents, currency: currency);
  }
}