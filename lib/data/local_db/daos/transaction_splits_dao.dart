part of '../app_database.dart';

@DriftAccessor(tables: [TransactionSplits])
class TransactionSplitsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionSplitsDaoMixin {
  TransactionSplitsDao(AppDatabase db) : super(db);

  Stream<List<TransactionSplit>> watchByTransactionId(int txnId) {
    return (select(transactionSplits)
          ..where((s) => s.transactionId.equals(txnId))
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .watch();
  }

  Future<List<TransactionSplit>> getByTransactionId(int txnId) {
    return (select(transactionSplits)
          ..where((s) => s.transactionId.equals(txnId))
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
  }

  Future<int> insertOne(TransactionSplitsCompanion entry) =>
      into(transactionSplits).insert(entry);

  Future<int> deleteByTransactionId(int txnId) {
    return (delete(transactionSplits)
          ..where((s) => s.transactionId.equals(txnId)))
        .go();
  }

  /// Replace all splits for a transaction (atomic).
  Future<void> replaceForTransaction(
    int txnId,
    List<TransactionSplitsCompanion> splits,
  ) async {
    await transaction(() async {
      await deleteByTransactionId(txnId);
      if (splits.isNotEmpty) {
        await batch((b) {
          b.insertAll(transactionSplits, splits);
        });
      }
    });
  }
}