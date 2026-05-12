part of '../app_database.dart';

class BudgetCategorySummary {
  final int categoryId;
  final String categoryName;

  final int budgetId; // 0 if no budget row exists
  final int budgetCents;
  final int spentCents; // positive cents (abs of expense spending)
  final bool alert80Sent;
  final bool alert100Sent;

  BudgetCategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.budgetId,
    required this.budgetCents,
    required this.spentCents,
    required this.alert80Sent,
    required this.alert100Sent,
  });

  int get remainingCents => budgetCents - spentCents;
  double get pctUsed => budgetCents == 0 ? 0 : spentCents / budgetCents;
}

@DriftAccessor(tables: [Budgets, Categories, Transactions, TransactionSplits])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(AppDatabase db) : super(db);

  // --- basic CRUD ---
  Future<List<Budget>> byMonth(String month) =>
      (select(budgets)..where((t) => t.month.equals(month))).get();

  Stream<List<Budget>> watchByMonth(String month) =>
      (select(budgets)..where((t) => t.month.equals(month))).watch();

  Future<int> upsertBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry, mode: InsertMode.insertOrReplace);

  Future<void> setBudget({
    required String monthKey,
    required int categoryId,
    required int amountCents,
  }) async {
    await upsertBudget(
      BudgetsCompanion.insert(
        month: monthKey,
        categoryId: categoryId,
        amountCents: amountCents,
        // reset alerts when budget is edited
        alert80Sent: const Value(false),
        alert100Sent: const Value(false),
      ),
    );
  }

  Future<void> markAlertSent({
    required String monthKey,
    required int categoryId,
    required int level, // 80 or 100
  }) async {
    final q = update(budgets)
      ..where((b) => b.month.equals(monthKey) & b.categoryId.equals(categoryId));

    if (level >= 100) {
      await q.write(const BudgetsCompanion(
      alert80Sent: Value(true),
      alert100Sent: Value(true),
    ));
    } else if (level >= 80) {
      await q.write(const BudgetsCompanion(alert80Sent: Value(true)));
    }
  }

  // --- Copy previous month budgets ---
  String _prevMonthKey(String monthKey) {
    // monthKey "YYYY-MM"
    final parts = monthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);

    final prev = DateTime(y, m, 1).subtract(const Duration(days: 1));
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  Future<void> copyFromPreviousMonth(String targetMonthKey) async {
    final prevKey = _prevMonthKey(targetMonthKey);

    final prevBudgets = await (select(budgets)..where((b) => b.month.equals(prevKey))).get();

    if (prevBudgets.isEmpty) return;

    await transaction(() async {
      // overwrite behavior (simple + expected)
      await batch((b) {
        b.insertAll(
          budgets,
          prevBudgets.map((pb) {
            return BudgetsCompanion.insert(
              month: targetMonthKey,
              categoryId: pb.categoryId,
              amountCents: pb.amountCents,
              alert80Sent: const Value(false),
              alert100Sent: const Value(false),
            );
          }).toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  // --- Monthly overview including SPLITS spending ---
  DateTime _startOfMonth(String monthKey) {
    final parts = monthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(y, m, 1);
  }

  DateTime _startOfNextMonth(String monthKey) {
    final s = _startOfMonth(monthKey);
    return DateTime(s.year, s.month + 1, 1);
  }

  /// Stream: For all EXPENSE categories, return budget/spent/alerts for the month.
  /// Spent includes:
  /// - non-split txns (transactions.category_id)
  /// - split txns (transaction_splits.category_id joined via transactions for date filter)
  ///
  /// Assumption from Phase 2:
  /// - expense amounts are stored NEGATIVE
  /// - income amounts are stored POSITIVE
  /// We report spentCents as POSITIVE ABS value.
  Stream<List<BudgetCategorySummary>> watchMonthCategorySummary(
    String monthKey, {
    bool rollover = false,
    bool rolloverOnlyPositive = true,
  }) {
    final start = _startOfMonth(monthKey);
    final end = _startOfNextMonth(monthKey);

    final prevKey = _prevMonthKey(monthKey);
    final prevStart = _startOfMonth(prevKey);
    final prevEnd = _startOfNextMonth(prevKey);

    final rolloverEnabled = rollover ? 1 : 0;
    final rolloverOnlyPos = rolloverOnlyPositive ? 1 : 0;

    // SQL notes:
    // - txn_spent: non-split txns where t.category_id is NOT NULL
    // - split_spent: split rows joined to transactions for txn date
    // - spent: union & sum
    //
    // For expenses stored negative, ABS(SUM(...)) gives positive "spent".
    const sql = r'''
WITH
-- ---------------- Current month spent (non-split + split) ----------------
txn_spent AS (
  SELECT t.category_id AS category_id,
         ABS(SUM(t.amount_cents)) AS spent_cents
  FROM transactions t
  JOIN categories c ON c.id = t.category_id
  WHERE t.category_id IS NOT NULL
    AND c.type = 'expense'
    AND t.txn_at >= ?1 AND t.txn_at < ?2
  GROUP BY t.category_id
),
split_spent AS (
  SELECT s.category_id AS category_id,
         ABS(SUM(s.amount_cents)) AS spent_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  JOIN categories c ON c.id = s.category_id
  WHERE c.type = 'expense'
    AND t.txn_at >= ?3 AND t.txn_at < ?4
  GROUP BY s.category_id
),
spent AS (
  SELECT category_id, SUM(spent_cents) AS spent_cents
  FROM (
    SELECT * FROM txn_spent
    UNION ALL
    SELECT * FROM split_spent
  )
  GROUP BY category_id
),

-- ---------------- Previous month spent (for rollover) ----------------
prev_txn_spent AS (
  SELECT t.category_id AS category_id,
         ABS(SUM(t.amount_cents)) AS spent_cents
  FROM transactions t
  JOIN categories c ON c.id = t.category_id
  WHERE t.category_id IS NOT NULL
    AND c.type = 'expense'
    AND t.txn_at >= ?6 AND t.txn_at < ?7
  GROUP BY t.category_id
),
prev_split_spent AS (
  SELECT s.category_id AS category_id,
         ABS(SUM(s.amount_cents)) AS spent_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  JOIN categories c ON c.id = s.category_id
  WHERE c.type = 'expense'
    AND t.txn_at >= ?8 AND t.txn_at < ?9
  GROUP BY s.category_id
),
prev_spent AS (
  SELECT category_id, SUM(spent_cents) AS spent_cents
  FROM (
    SELECT * FROM prev_txn_spent
    UNION ALL
    SELECT * FROM prev_split_spent
  )
  GROUP BY category_id
),

-- ---------------- Carry-in (remaining from previous month) ----------------
-- remaining_prev = prev_budget - prev_spent
-- If rolloverOnlyPositive=1, only carry positive remaining.
carry AS (
  SELECT
    c.id AS category_id,
    CASE
      WHEN ?11 = 0 THEN 0
      WHEN COALESCE(bp.amount_cents, 0) <= 0 THEN 0
      ELSE
        CASE
          WHEN ?12 = 1 THEN MAX(COALESCE(bp.amount_cents, 0) - COALESCE(ps.spent_cents, 0), 0)
          ELSE (COALESCE(bp.amount_cents, 0) - COALESCE(ps.spent_cents, 0))
        END
    END AS carry_cents
  FROM categories c
  LEFT JOIN budgets bp
    ON bp.category_id = c.id AND bp.month = ?10
  LEFT JOIN prev_spent ps
    ON ps.category_id = c.id
  WHERE c.type = 'expense'
)

SELECT
  c.id AS category_id,
  c.name AS category_name,
  COALESCE(b.id, 0) AS budget_id,

  -- Effective budget = current month budget + carry (only when rollover enabled AND current budget > 0)
  (
    COALESCE(b.amount_cents, 0)
    + CASE
        WHEN (?11 = 1 AND COALESCE(b.amount_cents, 0) > 0) THEN COALESCE(ca.carry_cents, 0)
        ELSE 0
      END
  ) AS budget_cents,

  COALESCE(sp.spent_cents, 0) AS spent_cents,
  COALESCE(b.alert_80_sent, 0) AS alert_80_sent,
  COALESCE(b.alert_100_sent, 0) AS alert_100_sent
FROM categories c
LEFT JOIN budgets b
  ON b.category_id = c.id AND b.month = ?5
LEFT JOIN spent sp
  ON sp.category_id = c.id
LEFT JOIN carry ca
  ON ca.category_id = c.id
WHERE c.type = 'expense'
ORDER BY c.name COLLATE NOCASE;
''';

    final query = customSelect(
      sql,
      variables: [
        // current month window
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<DateTime>(start),
        Variable<DateTime>(end),

        // month key for current budgets
        Variable<String>(monthKey),

        // previous month window (for rollover)
        Variable<DateTime>(prevStart),
        Variable<DateTime>(prevEnd),
        Variable<DateTime>(prevStart),
        Variable<DateTime>(prevEnd),

        // previous month key (for rollover budgets)
        Variable<String>(prevKey),

        // rollover flags
        Variable<int>(rolloverEnabled),
        Variable<int>(rolloverOnlyPos),
      ],
      readsFrom: {categories, budgets, transactions, transactionSplits},
    );

    return query.watch().map((rows) {
      return rows.map((r) {
        return BudgetCategorySummary(
          categoryId: r.read<int>('category_id'),
          categoryName: r.read<String>('category_name'),
          budgetId: r.read<int>('budget_id'),
          budgetCents: r.read<int>('budget_cents'),
          spentCents: r.read<int>('spent_cents'),
          alert80Sent: r.read<bool>('alert_80_sent'),
          alert100Sent: r.read<bool>('alert_100_sent'),
        );
      }).toList();
    });
  }
}