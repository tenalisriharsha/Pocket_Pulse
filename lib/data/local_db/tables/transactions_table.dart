import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  IntColumn get amountCents => integer()(); // store cents to avoid float issues
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get txnAt => dateTime()(); // when the transaction happened
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}