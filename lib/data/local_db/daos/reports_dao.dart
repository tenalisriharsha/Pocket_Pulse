part of '../app_database.dart';

class MonthSummary {
  final int incomeCents; // positive
  final int expenseCents; // positive
  MonthSummary({
    required this.incomeCents,
    required this.expenseCents,
  });

  int get netCents => incomeCents - expenseCents;
}

class CategorySpendRow {
  final int categoryId; // can be -1 for Uncategorized
  final String categoryName;
  final int spentCents; // positive
  CategorySpendRow({
    required this.categoryId,
    required this.categoryName,
    required this.spentCents,
  });
}

class TrendPoint {
  final String monthKey; // YYYY-MM
  final int expenseCents; // positive (for income trend we still reuse this field as "spentCents")
  TrendPoint({
    required this.monthKey,
    required this.expenseCents,
  });
}

class MerchantSpendRow {
  final String merchant;
  final int spentCents; // positive
  MerchantSpendRow({
    required this.merchant,
    required this.spentCents,
  });
}

@DriftAccessor(tables: [Transactions, TransactionSplits, Categories])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(AppDatabase db) : super(db);

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

  String _monthKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  List<String> _monthKeysBackFrom(String monthKey, int monthsBack) {
    final start = _startOfMonth(monthKey);
    final keys = <String>[];
    for (var i = monthsBack - 1; i >= 0; i--) {
      final dt = DateTime(start.year, start.month - i, 1);
      keys.add(_monthKeyFromDate(dt));
    }
    return keys;
  }

  int _idOrZero(int? v) => v ?? 0;

  /// Month summary including splits.
  /// Income is any positive amount.
  /// Expense is any negative amount.
  /// Category filter applies to txn.categoryId or split.categoryId when provided.
  Stream<MonthSummary> watchMonthSummary(
    String monthKey, {
    int? accountId,
    int? categoryId,
  }) {
    final start = _startOfMonth(monthKey);
    final end = _startOfNextMonth(monthKey);

    final cid = _idOrZero(categoryId);
    final aid = _idOrZero(accountId);

    const sql = r'''
WITH
income_txn AS (
  SELECT COALESCE(SUM(CASE WHEN t.amount_cents > 0 THEN t.amount_cents ELSE 0 END), 0) AS income_cents
  FROM transactions t
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR t.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
),
income_split AS (
  SELECT COALESCE(SUM(CASE WHEN s.amount_cents > 0 THEN s.amount_cents ELSE 0 END), 0) AS income_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR s.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
),
expense_txn AS (
  SELECT COALESCE(SUM(CASE WHEN t.amount_cents < 0 THEN ABS(t.amount_cents) ELSE 0 END), 0) AS expense_cents
  FROM transactions t
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR t.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
),
expense_split AS (
  SELECT COALESCE(SUM(CASE WHEN s.amount_cents < 0 THEN ABS(s.amount_cents) ELSE 0 END), 0) AS expense_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR s.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
)
SELECT
  (SELECT income_cents FROM income_txn) + (SELECT income_cents FROM income_split) AS income_cents,
  (SELECT expense_cents FROM expense_txn) + (SELECT expense_cents FROM expense_split) AS expense_cents;
''';

    final q = customSelect(
      sql,
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(cid),
        Variable<int>(aid),
      ],
      readsFrom: {transactions, transactionSplits},
    );

    return q.watchSingle().map((r) {
      return MonthSummary(
        incomeCents: r.read<int>('income_cents'),
        expenseCents: r.read<int>('expense_cents'),
      );
    });
  }

  /// Spend by category for either expense or income, including splits.
  /// Includes Uncategorized bucket when category is null.
  Stream<List<CategorySpendRow>> watchSpendByCategory(
    String monthKey, {
    required String type, // expense or income
    int? accountId,
    int? categoryId,
  }) {
    final start = _startOfMonth(monthKey);
    final end = _startOfNextMonth(monthKey);

    final cid = _idOrZero(categoryId);
    final aid = _idOrZero(accountId);

    const sql = r'''
WITH
txn_spend AS (
  SELECT
    COALESCE(t.category_id, -1) AS category_id,
    COALESCE(c.name, 'Uncategorized') AS category_name,
    COALESCE(SUM(
      CASE
        WHEN ?5 = 'income' AND t.amount_cents > 0 THEN t.amount_cents
        WHEN ?5 = 'expense' AND t.amount_cents < 0 THEN ABS(t.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transactions t
  LEFT JOIN categories c ON c.id = t.category_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR t.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY COALESCE(t.category_id, -1), COALESCE(c.name, 'Uncategorized')
),
split_spend AS (
  SELECT
    COALESCE(s.category_id, -1) AS category_id,
    COALESCE(c.name, 'Uncategorized') AS category_name,
    COALESCE(SUM(
      CASE
        WHEN ?5 = 'income' AND s.amount_cents > 0 THEN s.amount_cents
        WHEN ?5 = 'expense' AND s.amount_cents < 0 THEN ABS(s.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  LEFT JOIN categories c ON c.id = s.category_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR s.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY COALESCE(s.category_id, -1), COALESCE(c.name, 'Uncategorized')
),
spent AS (
  SELECT category_id, category_name, SUM(spent_cents) AS spent_cents
  FROM (
    SELECT * FROM txn_spend
    UNION ALL
    SELECT * FROM split_spend
  )
  GROUP BY category_id, category_name
)
SELECT category_id, category_name, spent_cents
FROM spent
WHERE spent_cents > 0
ORDER BY spent_cents DESC, category_name COLLATE NOCASE;
''';

    final q = customSelect(
      sql,
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(cid),
        Variable<int>(aid),
        Variable<String>(type),
      ],
      readsFrom: {transactions, transactionSplits, categories},
    );

    return q.watch().map((rows) {
      return rows.map((r) {
        return CategorySpendRow(
          categoryId: r.read<int>('category_id'),
          categoryName: r.read<String>('category_name'),
          spentCents: r.read<int>('spent_cents'),
        );
      }).toList();
    });
  }

  /// Top merchants by type (expense or income), including splits.
  /// Uses sign of amount to decide income vs expense.
  Stream<List<MerchantSpendRow>> watchTopMerchantsByType(
    String monthKey, {
    required String type, // expense or income
    int limit = 7,
    int? accountId,
    int? categoryId,
  }) {
    final start = _startOfMonth(monthKey);
    final end = _startOfNextMonth(monthKey);

    final cid = _idOrZero(categoryId);
    final aid = _idOrZero(accountId);

    const sql = r'''
WITH
txn_merch AS (
  SELECT
    COALESCE(NULLIF(TRIM(t.merchant), ''), 'Unknown') AS merchant,
    COALESCE(SUM(
      CASE
        WHEN ?6 = 'income' AND t.amount_cents > 0 THEN t.amount_cents
        WHEN ?6 = 'expense' AND t.amount_cents < 0 THEN ABS(t.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transactions t
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR t.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY merchant
),
split_merch AS (
  SELECT
    COALESCE(NULLIF(TRIM(t.merchant), ''), 'Unknown') AS merchant,
    COALESCE(SUM(
      CASE
        WHEN ?6 = 'income' AND s.amount_cents > 0 THEN s.amount_cents
        WHEN ?6 = 'expense' AND s.amount_cents < 0 THEN ABS(s.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR s.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY merchant
),
spent AS (
  SELECT merchant, SUM(spent_cents) AS spent_cents
  FROM (
    SELECT * FROM txn_merch
    UNION ALL
    SELECT * FROM split_merch
  )
  GROUP BY merchant
)
SELECT merchant, spent_cents
FROM spent
WHERE spent_cents > 0
ORDER BY spent_cents DESC, merchant COLLATE NOCASE
LIMIT ?5;
''';

    final q = customSelect(
      sql,
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(cid),
        Variable<int>(aid),
        Variable<int>(limit),
        Variable<String>(type),
      ],
      readsFrom: {transactions, transactionSplits},
    );

    return q.watch().map((rows) {
      return rows.map((r) {
        return MerchantSpendRow(
          merchant: r.read<String>('merchant'),
          spentCents: r.read<int>('spent_cents'),
        );
      }).toList();
    });
  }

  /// Trend by type over last monthsBack months.
  /// Uses sign of amount to decide income vs expense.
  Stream<List<TrendPoint>> watchTrendByType({
    required String monthKey,
    required String type, // expense or income
    int monthsBack = 6,
    int? accountId,
    int? categoryId,
  }) {
    final keys = _monthKeysBackFrom(monthKey, monthsBack);
    final start = _startOfMonth(keys.first);
    final end = _startOfNextMonth(keys.last);

    final cid = _idOrZero(categoryId);
    final aid = _idOrZero(accountId);

    const sql = r'''
WITH
txn_month AS (
  SELECT
    strftime('%Y-%m', datetime(t.txn_at, 'unixepoch', 'localtime')) AS month_key,
    COALESCE(SUM(
      CASE
        WHEN ?5 = 'income' AND t.amount_cents > 0 THEN t.amount_cents
        WHEN ?5 = 'expense' AND t.amount_cents < 0 THEN ABS(t.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transactions t
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR t.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY month_key
),
split_month AS (
  SELECT
    strftime('%Y-%m', datetime(t.txn_at, 'unixepoch', 'localtime')) AS month_key,
    COALESCE(SUM(
      CASE
        WHEN ?5 = 'income' AND s.amount_cents > 0 THEN s.amount_cents
        WHEN ?5 = 'expense' AND s.amount_cents < 0 THEN ABS(s.amount_cents)
        ELSE 0
      END
    ), 0) AS spent_cents
  FROM transaction_splits s
  JOIN transactions t ON t.id = s.transaction_id
  WHERE t.txn_at >= ?1 AND t.txn_at < ?2
    AND (?3 = 0 OR s.category_id = ?3)
    AND (?4 = 0 OR t.account_id = ?4)
  GROUP BY month_key
),
spent AS (
  SELECT month_key, SUM(spent_cents) AS spent_cents
  FROM (
    SELECT * FROM txn_month
    UNION ALL
    SELECT * FROM split_month
  )
  GROUP BY month_key
)
SELECT month_key, COALESCE(spent_cents, 0) AS spent_cents
FROM spent
ORDER BY month_key ASC;
''';

    final q = customSelect(
      sql,
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        Variable<int>(cid),
        Variable<int>(aid),
        Variable<String>(type),
      ],
      readsFrom: {transactions, transactionSplits},
    );

    return q.watch().map((rows) {
      final map = <String, int>{};
      for (final r in rows) {
        map[r.read<String>('month_key')] = r.read<int>('spent_cents');
      }

      return keys
          .map((k) => TrendPoint(monthKey: k, expenseCents: map[k] ?? 0))
          .toList();
    });
  }
}