part of '../app_database.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(AppDatabase db) : super(db);

  Future<List<Account>> getAll() => select(accounts).get();
  Stream<List<Account>> watchAll() => select(accounts).watch();

  Future<int> insertOne(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateOne(Account item) => update(accounts).replace(item);

  Future<int> deleteById(int id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();
}