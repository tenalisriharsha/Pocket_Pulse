import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// A standardized money display widget used everywhere in PocketPulse.
/// Values are always larger and bolder than surrounding labels.
class MoneyText extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final bool showSign;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  const MoneyText({
    super.key,
    required this.cents,
    this.style,
    this.showSign = true,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w700,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = cents < 0;
    final baseColor = isNegative ? Colors.red.shade700 : Colors.green.shade700;

    return Text(
      Formatters.money(cents),
      style: style ??
          TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color ?? baseColor,
            letterSpacing: -0.4,
            height: 1.1,
          ),
    );
  }
}

/// A smaller, muted money label for subtitles and captions.
class MoneyLabel extends StatelessWidget {
  final int cents;
  final TextStyle? style;

  const MoneyLabel({super.key, required this.cents, this.style});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      Formatters.money(cents),
      style: style ??
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
    );
  }
}
