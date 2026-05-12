import 'package:pocket_pulse/data/local_db/app_database.dart';

class CategoriesRepository {
  final AppDatabase db;
  CategoriesRepository(this.db);

  Stream<List<Category>> watchAll() => db.categoriesDao.watchAll();
  Future<List<Category>> getAll() => db.categoriesDao.getAll();

  Future<int> create({required String name, required String type}) {
    return db.categoriesDao.insertOne(
      CategoriesCompanion.insert(
        name: name,
        type: type, // "expense" or "income"
      ),
    );
  }

  Future<void> deleteById(int id) => db.categoriesDao.deleteById(id);
}