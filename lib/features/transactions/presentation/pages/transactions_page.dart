import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:pocket_pulse/shared/animations/animated_counter.dart';
import 'package:pocket_pulse/shared/animations/confetti_overlay.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/hover_card.dart';

import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';
import 'package:pocket_pulse/shared/widgets/money_text.dart';

import 'add_transaction_page.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  int? _accountId;
  int? _categoryId;
  DateTime? _from;
  DateTime? _to;

  static const _pageSize = 50;
  int _limit = _pageSize;

  void _clearFilters() {
    setState(() {
      _accountId = null;
      _categoryId = null;
      _from = null;
      _to = null;
      _limit = _pageSize;
    });
  }

  bool get _hasFilters =>
      _accountId != null || _categoryId != null || _from != null || _to != null;

  TransactionsCompanion _companionFromTxn(Transaction t) {
    return TransactionsCompanion.insert(
      accountId: t.accountId,
      categoryId: t.categoryId == null ? const Value.absent() : Value(t.categoryId!),
      amountCents: t.amountCents,
      merchant: (t.merchant == null || t.merchant!.trim().isEmpty)
          ? const Value.absent()
          : Value(t.merchant!.trim()),
      note: (t.note == null || t.note!.trim().isEmpty)
          ? const Value.absent()
          : Value(t.note!.trim()),
      txnAt: t.txnAt,
    );
  }

  Future<bool> _confirmDelete(String titleText) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('This will delete "$titleText".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return shouldDelete ?? false;
  }

  void _showUndoSnack({
    required AppDatabase db,
    required Transaction deletedTxn,
    required List<TransactionSplit> deletedSplits,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              final newTxnId = await db.transactionsDao.insertOne(
                _companionFromTxn(deletedTxn),
              );
              if (deletedSplits.isNotEmpty) {
                final splitCompanions = deletedSplits.map((s) {
                  return TransactionSplitsCompanion(
                    transactionId: const Value.absent(),
                    categoryId: Value(s.categoryId),
                    amountCents: Value(s.amountCents),
                  );
                }).toList();
                await db.transactionsDao.replaceSplits(newTxnId, splitCompanions);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restored')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Undo failed: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(AppDatabase db) async {
    final accounts = await db.accountsDao.getAll();
    final categories = await db.categoriesDao.getAll();
    if (!mounted) return;

    int? tempAccount = _accountId;
    int? tempCategory = _categoryId;
    DateTime? tempFrom = _from;
    DateTime? tempTo = _to;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Filters',
                      style: Theme.of(ctx).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: tempAccount,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All accounts')),
                      ...accounts.map((a) => DropdownMenuItem<int?>(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => tempAccount = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: tempCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                      ...categories.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setLocal(() => tempCategory = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempFrom ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocal(() => tempFrom = Formatters.startOfDay(picked));
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(tempFrom == null ? 'From' : Formatters.date(tempFrom!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempTo ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocal(() => tempTo = Formatters.endOfDay(picked));
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(tempTo == null ? 'To' : Formatters.date(tempTo!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _accountId = tempAccount;
                        _categoryId = tempCategory;
                        _from = tempFrom;
                        _to = tempTo;
                        _limit = _pageSize;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          if (_hasFilters)
            IconButton(
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(db),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          );
          if (ok == true && mounted) {
            ConfettiHelper.burst(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction saved')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Active filter chips
          if (_hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FadeSlideIn(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_accountId != null)
                      StreamBuilder<List<Account>>(
                        stream: db.accountsDao.watchAll(),
                        builder: (context, snap) {
                          final name = snap.data?.firstWhere(
                                (a) => a.id == _accountId,
                                orElse: () => snap.data!.first,
                              ).name ??
                              'Account';
                          return Chip(
                            label: Text(name),
                            onDeleted: () => setState(() {
                              _accountId = null;
                              _limit = _pageSize;
                            }),
                          );
                        },
                      ),
                    if (_categoryId != null)
                      StreamBuilder<List<Category>>(
                        stream: db.categoriesDao.watchAll(),
                        builder: (context, snap) {
                          final name = snap.data?.firstWhere(
                                (c) => c.id == _categoryId,
                                orElse: () => snap.data!.first,
                              ).name ??
                              'Category';
                          return Chip(
                            label: Text(name),
                            onDeleted: () => setState(() {
                              _categoryId = null;
                              _limit = _pageSize;
                            }),
                          );
                        },
                      ),
                    if (_from != null)
                      Chip(
                        label: Text('From ${Formatters.date(_from!)}'),
                        onDeleted: () => setState(() {
                          _from = null;
                          _limit = _pageSize;
                        }),
                      ),
                    if (_to != null)
                      Chip(
                        label: Text('To ${Formatters.date(_to!)}'),
                        onDeleted: () => setState(() {
                          _to = null;
                          _limit = _pageSize;
                        }),
                      ),
                  ],
                ),
              ),
            ),

          // List
          Expanded(
            child: StreamBuilder<List<TxnRow>>(
              stream: db.transactionsDao.watchWithFilters(
                accountId: _accountId,
                categoryId: _categoryId,
                from: _from,
                to: _to,
              ),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Transactions stream error:\n${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRows = snap.data!;
                if (allRows.isEmpty) {
                  return FadeSlideIn(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: cs.outline),
                          const SizedBox(height: 12),
                          Text('No transactions yet',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Tap + to add one',
                              style: TextStyle(color: cs.outline, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                final totalCents = allRows.fold<int>(0, (sum, r) => sum + r.txn.amountCents);
                final hasMore = allRows.length > _limit;
                final rows = hasMore ? allRows.sublist(0, _limit) : allRows;

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length + 1 + (hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return FadeSlideIn(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AnimatedCounter(
                                target: totalCents,
                                formatter: (v) => 'Net Total: ${Formatters.money(v)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${allRows.length} txns',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (i == rows.length + 1) {
                      return FadeSlideIn(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: TextButton.icon(
                              onPressed: () => setState(() => _limit += _pageSize),
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Load more'),
                            ),
                          ),
                        ),
                      );
                    }

                    final r = rows[i - 1];
                    final txn = r.txn;
                    final account = r.account;
                    final category = r.category;
                    final isSplit = txn.categoryId == null;
                    final titleText =
                        (txn.merchant != null && txn.merchant!.trim().isNotEmpty)
                            ? txn.merchant!
                            : (category?.name ?? (isSplit ? 'Split Transaction' : 'Transaction'));
                    final isExpense = txn.amountCents < 0;

                    return FadeSlideIn(
                      delay: Duration(milliseconds: (i % 8) * 30),
                      child: Dismissible(
                        key: ValueKey('txn-${txn.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDelete(titleText),
                        onDismissed: (_) async {
                          final deletedTxn = txn;
                          final deletedSplits = await db.transactionsDao.getSplits(deletedTxn.id);
                          try {
                            await db.transactionsDao.deleteById(deletedTxn.id);
                            if (mounted) {
                              _showUndoSnack(
                                db: db,
                                deletedTxn: deletedTxn,
                                deletedSplits: deletedSplits,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Delete failed: $e')),
                              );
                            }
                          }
                        },
                        child: HoverCard(
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isExpense
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                                child: Icon(
                                  isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                              title: Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${account.name} \u2022 ${category?.name ?? (isSplit ? 'Split' : 'No category')} \u2022 ${Formatters.date(txn.txnAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MoneyText(
                                    cents: txn.amountCents,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () async {
                                      final ok = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => AddTransactionPage(existing: txn),
                                        ),
                                      );
                                      if (ok == true && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Transaction updated')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
