import 'package:drift/drift.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();
  IntColumn get targetAmountCents => integer()();
  IntColumn get currentAmountCents => integer().withDefault(const Constant(0))();

  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}