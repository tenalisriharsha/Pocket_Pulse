import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';

/// Filters state (account/category/date range)
class TxnFilters {
  final int? accountId;
  final int? categoryId;
  final DateTime? from;
  final DateTime? to;

  const TxnFilters({
    this.accountId,
    this.categoryId,
    this.from,
    this.to,
  });

  TxnFilters copyWith({
    int? accountId,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    bool clearAccount = false,
    bool clearCategory = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return TxnFilters(
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }
}

final txnFiltersProvider = StateProvider<TxnFilters>((ref) {
  return const TxnFilters();
});

/// Needed for dropdowns
final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountsDao.watchAll();
});

/// Main transactions list (joined rows) using your DAO method
final transactionsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final f = ref.watch(txnFiltersProvider);

  return db.transactionsDao.watchWithFilters(
    accountId: f.accountId,
    categoryId: f.categoryId,
    from: f.from,
    to: f.to,
  );
});
