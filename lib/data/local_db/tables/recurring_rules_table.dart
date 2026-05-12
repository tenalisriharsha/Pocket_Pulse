import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get amountCents => integer()();
  TextColumn get type => text()(); // expense / income

  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  TextColumn get frequency => text()(); // daily/weekly/monthly/yearly
  IntColumn get interval => integer().withDefault(const Constant(1))(); // every N

  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get lastPaidAt => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}