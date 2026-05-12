import 'package:drift/drift.dart';

import 'connection.dart';

// Tables
import 'tables/categories_table.dart';
import 'tables/accounts_table.dart';
import 'tables/transactions_table.dart';
import 'tables/transaction_splits_table.dart';
import 'tables/budgets_table.dart';
import 'tables/recurring_rules_table.dart';
import 'tables/goals_table.dart';

// DAOs as PARTS (Option A)
part 'daos/categories_dao.dart';
part 'daos/accounts_dao.dart';
part 'daos/transactions_dao.dart';
part 'daos/budgets_dao.dart';
part 'daos/recurring_rules_dao.dart';
part 'daos/goals_dao.dart';
part 'daos/transaction_splits_dao.dart';

// ✅ Phase 5 Reports DAO
part 'daos/reports_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Accounts,
    Transactions,
    TransactionSplits,
    Budgets,
    RecurringRules,
    Goals,
  ],
  daos: [
    CategoriesDao,
    AccountsDao,
    TransactionsDao,
    BudgetsDao,
    RecurringRulesDao,
    GoalsDao,
    TransactionSplitsDao,

    // ✅ Phase 5
    ReportsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(driftDatabase(name: 'pocketpulse_db'));
  static final AppDatabase instance = AppDatabase._internal();
  factory AppDatabase() => instance;

  // ✅ still 3 (no schema changes for Phase 5)
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(accounts);
            await m.createTable(transactions);
            await m.createTable(transactionSplits);
            await m.createTable(budgets);
            await m.createTable(recurringRules);
            await m.createTable(goals);
          }

          if (from >= 2 && from < 3) {
            await m.addColumn(budgets, budgets.alert80Sent);
            await m.addColumn(budgets, budgets.alert100Sent);
          }
        },
      );
}