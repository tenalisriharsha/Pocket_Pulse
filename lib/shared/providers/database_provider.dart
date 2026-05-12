import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  // Use your singleton instance (Option A)
  final db = AppDatabase.instance;
  return db;
});