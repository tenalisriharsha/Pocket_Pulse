import 'package:drift/drift.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g., Chase Checking
  TextColumn get type => text()(); // cash/checking/savings/credit
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get openingBalanceCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}