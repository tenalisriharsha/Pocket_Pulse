import 'package:drift/drift.dart';

import 'transactions_table.dart';
import 'categories_table.dart';

class TransactionSplits extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  IntColumn get amountCents => integer()();
}