import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // "expense" or "income"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}