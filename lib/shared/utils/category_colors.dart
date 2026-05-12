import 'package:flutter/material.dart';

/// Consistent color mapping for categories across the entire app.
/// Used by donut charts, list icons, and progress bars.
class CategoryColors {
  CategoryColors._();

  static const List<Color> palette = [
    Color(0xFF2196F3), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
    Color(0xFFFF5722), // deep orange
    Color(0xFF3F51B5), // indigo
    Color(0xFF8BC34A), // light green
    Color(0xFF795548), // brown
    Color(0xFF607D8B), // blue grey
    Color(0xFF009688), // teal
  ];

  /// Get a stable color for a category based on its index.
  static Color forIndex(int i) => palette[i % palette.length];

  /// Get a light background tint for the same index.
  static Color bgForIndex(int i) => forIndex(i).withValues(alpha: 0.12);
}
