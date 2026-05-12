part of '../app_database.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(AppDatabase db) : super(db);

  Future<int> countCategories() async {
    final row = await customSelect('SELECT COUNT(*) AS c FROM categories')
        .getSingle();
    final value = row.data['c'];
    return (value is int) ? value : (value as num).toInt();
  }

  Future<List<Category>> getAll() => select(categories).get();

  Stream<List<Category>> watchAll() => select(categories).watch();

  Future<int> insertOne(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<void> insertMany(List<CategoriesCompanion> entries) async {
    await batch((b) => b.insertAll(categories, entries));
  }

  Future<bool> updateOne(Category item) => update(categories).replace(item);

  Future<int> deleteById(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();
}