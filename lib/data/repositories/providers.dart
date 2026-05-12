import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/data/repositories/categories_repository.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoriesRepository(db);
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoriesRepositoryProvider);
  return repo.watchAll();
});
