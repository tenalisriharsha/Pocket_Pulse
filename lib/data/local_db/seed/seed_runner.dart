import 'dart:convert';
import 'package:flutter/services.dart';
import '../app_database.dart';

class SeedRunner {
  final AppDatabase db;
  SeedRunner(this.db);

  Future<void> seedDefaultCategoriesIfEmpty() async {
    final count = await db.categoriesDao.countCategories();
    if (count > 0) return;

    final raw = await rootBundle.loadString('assets/seed/default_categories.json');
    final List<dynamic> decoded = jsonDecode(raw);

    final entries = decoded.map((e) {
      return CategoriesCompanion.insert(
        name: (e['name'] as String).trim(),
        type: (e['type'] as String).trim(),
      );
    }).toList();

    await db.categoriesDao.insertMany(entries);
  }
}
