part of '../app_database.dart';

/// A UI-friendly row that includes transaction + its account + optional category.
class TxnRow {
  final Transaction txn;
  final Account account;
  final Category? category;

  TxnRow({
    required this.txn,
    required this.account,
    required this.category,
  });
}

@DriftAccessor(tables: [Transactions, TransactionSplits, Accounts, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(AppDatabase db) : super(db);

  Future<List<Transaction>> getAll() => select(transactions).get();

  Stream<List<Transaction>> watchAll() => select(transactions).watch();

  Future<int> insertOne(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateOne(Transaction item) => update(transactions).replace(item);

  Future<Transaction?> getById(int id) {
    return (select(transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // -------------------- SPLITS HELPERS --------------------

  /// Load all splits for a transaction.
  Future<List<TransactionSplit>> getSplits(int txnId) {
    return (select(transactionSplits)
          ..where((s) => s.transactionId.equals(txnId)))
        .get();
  }

  /// Replace splits for a transaction (atomic):
  /// 1) delete old splits
  /// 2) insert provided splits
  ///
  /// NOTE: companions can omit transactionId; we will enforce it here.
  Future<void> replaceSplits(
    int txnId,
    List<TransactionSplitsCompanion> splits,
  ) async {
    await transaction(() async {
      // delete old splits first
      await (delete(transactionSplits)
            ..where((s) => s.transactionId.equals(txnId)))
          .go();

      if (splits.isEmpty) return;

      // insert new splits (ensure txnId is set)
      await batch((b) {
        b.insertAll(
          transactionSplits,
          splits.map((c) {
            return c.copyWith(transactionId: Value(txnId));
          }).toList(),
        );
      });
    });
  }

  // -------------------- DELETE (CASCADE) --------------------

  /// Delete a transaction AND its splits safely (atomic).
  Future<int> deleteTxnCascade(int txnId) async {
    return transaction(() async {
      // delete splits first (FK safety)
      await (delete(transactionSplits)
            ..where((s) => s.transactionId.equals(txnId)))
          .go();

      // then delete txn
      return (delete(transactions)..where((t) => t.id.equals(txnId))).go();
    });
  }

  /// Backward-compatible: deleteById also cascades.
  Future<int> deleteById(int id) => deleteTxnCascade(id);

  // -------------------- LIST JOIN (FOR UI) --------------------

  /// Joined stream for UI (txn + account + optional category) + filters.
  ///
  /// NOTE:
  /// - categoryId filter matches either the txn's primary categoryId OR any split row categoryId.
  /// - split transactions typically have txn.categoryId NULL (by design), so this OR logic is required.
  Stream<List<TxnRow>> watchWithFilters({
    int? accountId,
    int? categoryId,
    DateTime? from,
    DateTime? to,
  }) {
    final t = transactions;
    final a = accounts;
    final c = categories;

    final query = select(t).join([
      innerJoin(a, a.id.equalsExp(t.accountId)),
      leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
    ]);

    if (accountId != null) {
      query.where(t.accountId.equals(accountId));
    }

    if (categoryId != null) {
      // Match either:
      // 1) non-split txn with primary categoryId
      // 2) split txn that has ANY split row with this categoryId
      final splitTxnIds = selectOnly(transactionSplits)
        ..addColumns([transactionSplits.transactionId])
        ..where(transactionSplits.categoryId.equals(categoryId));

      query.where(
        t.categoryId.equals(categoryId) |
            t.id.isInQuery(splitTxnIds),
      );
    }

    if (from != null) {
      query.where(t.txnAt.isBiggerOrEqualValue(from));
    }

    if (to != null) {
      query.where(t.txnAt.isSmallerOrEqualValue(to));
    }

    query.orderBy([OrderingTerm.desc(t.txnAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TxnRow(
          txn: row.readTable(t),
          account: row.readTable(a),
          category: row.readTableOrNull(c),
        );
      }).toList();
    });
  }
}