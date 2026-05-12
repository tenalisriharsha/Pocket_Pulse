import 'package:drift/drift.dart';
import 'categories_table.dart';

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  // store month as "YYYY-MM" for easy filtering
  TextColumn get month => text()();

  IntColumn get categoryId => integer().references(Categories, #id)();

  // budgeted amount (cents)
  IntColumn get amountCents => integer()();

  // Phase 3: thresholds tracking (in-app)
  // Use stable column names for custom SQL.
  BoolColumn get alert80Sent =>
      boolean().named('alert_80_sent').withDefault(const Constant(false))();

  BoolColumn get alert100Sent =>
      boolean().named('alert_100_sent').withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {month, categoryId},
      ];
}