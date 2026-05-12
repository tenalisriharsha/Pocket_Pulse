import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/scale_tap.dart';
import 'package:pocket_pulse/shared/animations/shimmer.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';
import 'package:pocket_pulse/shared/widgets/animated_button.dart';

enum TxnKind { expense, income }

class _SplitDraft {
  int? categoryId;
  final TextEditingController amountCtrl;

  _SplitDraft({this.categoryId, String initialAmount = ''})
      : amountCtrl = TextEditingController(text: initialAmount);

  void dispose() => amountCtrl.dispose();
}

class AddTransactionPage extends ConsumerStatefulWidget {
  final Transaction? existing;

  const AddTransactionPage({super.key, this.existing});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _amountCtrl = TextEditingController();
  final _merchantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int? _accountId;
  int? _categoryId;
  DateTime _txnAt = DateTime.now();

  bool _isSplit = false;
  final List<_SplitDraft> _splits = [];

  TxnKind _manualKind = TxnKind.expense;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _txnAt = e.txnAt;
      _amountCtrl.text = (e.amountCents.abs() / 100).toStringAsFixed(2);
      _merchantCtrl.text = e.merchant ?? '';
      _noteCtrl.text = e.note ?? '';
      _manualKind = e.amountCents < 0 ? TxnKind.expense : TxnKind.income;
      Future.microtask(_loadSplitsIfAny);
    }
  }

  Future<void> _loadSplitsIfAny() async {
    final db = ref.read(databaseProvider);
    final e = widget.existing;
    if (e == null) return;
    final rows = await db.transactionsDao.getSplits(e.id);
    if (!mounted) return;
    if (rows.isNotEmpty) {
      setState(() {
        _isSplit = true;
        _splits.clear();
        for (final s in rows) {
          _splits.add(_SplitDraft(
            categoryId: s.categoryId,
            initialAmount: (s.amountCents.abs() / 100).toStringAsFixed(2),
          ));
        }
        _categoryId = null;
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    _noteCtrl.dispose();
    for (final s in _splits) s.dispose();
    super.dispose();
  }

  int _toCents(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned);
    if (value == null) return 0;
    return (value * 100).round();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _txnAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _txnAt = DateTime(picked.year, picked.month, picked.day, _txnAt.hour, _txnAt.minute);
    });
  }

  void _addSplitRow() => setState(() => _splits.add(_SplitDraft()));

  void _removeSplitRow(int index) {
    final s = _splits.removeAt(index);
    s.dispose();
    setState(() {});
  }

  Future<Category?> _getCategoryById(AppDatabase db, int id) {
    return (db.select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<TxnKind> _kindFromCategory(AppDatabase db, int categoryId) async {
    final cat = await _getCategoryById(db, categoryId);
    if (cat == null) return TxnKind.expense;
    return (cat.type == 'income') ? TxnKind.income : TxnKind.expense;
  }

  int _applyKindSign(int absCents, TxnKind kind) {
    final a = absCents.abs();
    return kind == TxnKind.expense ? -a : a;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      setState(() => _isSaving = false);
      return;
    }

    final absTxnCents = _toCents(_amountCtrl.text);
    if (absTxnCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      // SPLIT MODE
      if (_isSplit) {
        if (_splits.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add at least one split row')),
          );
          setState(() => _isSaving = false);
          return;
        }

        TxnKind? commonKind;
        int sumAbs = 0;
        final splitCompanions = <TransactionSplitsCompanion>[];

        for (final s in _splits) {
          if (s.categoryId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Each split must have a category')),
            );
            setState(() => _isSaving = false);
            return;
          }
          final absSplit = _toCents(s.amountCtrl.text);
          if (absSplit <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Split amounts must be > 0')),
            );
            setState(() => _isSaving = false);
            return;
          }
          final kind = await _kindFromCategory(db, s.categoryId!);
          commonKind ??= kind;
          if (commonKind != kind) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('All split categories must be all Expense or all Income')),
            );
            setState(() => _isSaving = false);
            return;
          }
          sumAbs += absSplit;
          splitCompanions.add(TransactionSplitsCompanion(
            transactionId: const Value.absent(),
            categoryId: Value(s.categoryId!),
            amountCents: Value(_applyKindSign(absSplit, kind)),
          ));
        }

        if (sumAbs != absTxnCents) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Splits must sum to ${(absTxnCents / 100).toStringAsFixed(2)}. '
                'Current sum: ${(sumAbs / 100).toStringAsFixed(2)}',
              ),
            ),
          );
          setState(() => _isSaving = false);
          return;
        }

        final totalSigned = _applyKindSign(absTxnCents, commonKind ?? TxnKind.expense);
        int txnId;

        if (_isEdit) {
          final e = widget.existing!;
          final txnCompanion = TransactionsCompanion(
            id: Value(e.id),
            accountId: Value(_accountId!),
            categoryId: const Value.absent(),
            amountCents: Value(totalSigned),
            merchant: _merchantCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(_merchantCtrl.text.trim()),
            note: _noteCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(_noteCtrl.text.trim()),
            txnAt: Value(_txnAt),
          );
          await db.update(db.transactions).replace(txnCompanion);
          txnId = e.id;
          await db.transactionsDao.replaceSplits(txnId, splitCompanions);
        } else {
          final insertCompanion = TransactionsCompanion.insert(
            accountId: _accountId!,
            categoryId: const Value.absent(),
            amountCents: totalSigned,
            merchant: _merchantCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(_merchantCtrl.text.trim()),
            note: _noteCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(_noteCtrl.text.trim()),
            txnAt: _txnAt,
          );
          txnId = await db.transactionsDao.insertOne(insertCompanion);
          await db.transactionsDao.replaceSplits(txnId, splitCompanions);
        }

        if (mounted) Navigator.pop(context, true);
        return;
      }

      // NON-SPLIT MODE
      TxnKind kind;
      if (_categoryId != null) {
        kind = await _kindFromCategory(db, _categoryId!);
      } else {
        kind = _manualKind;
      }

      final signedTxnCents = _applyKindSign(absTxnCents, kind);

      if (_isEdit) {
        final e = widget.existing!;
        final txnCompanion = TransactionsCompanion(
          id: Value(e.id),
          accountId: Value(_accountId!),
          categoryId: _categoryId == null ? const Value.absent() : Value(_categoryId!),
          amountCents: Value(signedTxnCents),
          merchant: _merchantCtrl.text.trim().isEmpty
              ? const Value.absent()
              : Value(_merchantCtrl.text.trim()),
          note: _noteCtrl.text.trim().isEmpty
              ? const Value.absent()
              : Value(_noteCtrl.text.trim()),
          txnAt: Value(_txnAt),
        );
        await db.update(db.transactions).replace(txnCompanion);
        await db.transactionsDao.replaceSplits(e.id, const []);
      } else {
        final insertCompanion = TransactionsCompanion.insert(
          accountId: _accountId!,
          categoryId: _categoryId == null ? const Value.absent() : Value(_categoryId!),
          amountCents: signedTxnCents,
          merchant: _merchantCtrl.text.trim().isEmpty
              ? const Value.absent()
              : Value(_merchantCtrl.text.trim()),
          note: _noteCtrl.text.trim().isEmpty
              ? const Value.absent()
              : Value(_noteCtrl.text.trim()),
          txnAt: _txnAt,
        );
        await db.transactionsDao.insertOne(insertCompanion);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Update failed: $e' : 'Insert failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account
          FadeSlideIn(
            child: StreamBuilder<List<Account>>(
              stream: db.accountsDao.watchAll(),
              builder: (context, snap) {
                if (snap.hasError) return Text('Accounts load error: ${snap.error}');
                if (!snap.hasData) return const Shimmer(child: SizedBox(height: 56));

                final accounts = snap.data!;
                if (!_isEdit && accounts.isNotEmpty && _accountId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _accountId == null) {
                      setState(() => _accountId = accounts.first.id);
                    }
                  });
                }

                return DropdownButtonFormField<int>(
                  value: _accountId,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    border: OutlineInputBorder(),
                  ),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 40),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Split transaction'),
              subtitle: const Text('Allocate this transaction across multiple categories'),
              value: _isSplit,
              onChanged: (v) {
                setState(() {
                  _isSplit = v;
                  if (_isSplit) {
                    _categoryId = null;
                    if (_splits.isEmpty) _addSplitRow();
                  }
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          // Category / Kind (non-split)
          if (!_isSplit)
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: StreamBuilder<List<Category>>(
                stream: db.categoriesDao.watchAll(),
                builder: (context, snap) {
                  if (snap.hasError) return Text('Categories load error: ${snap.error}');
                  if (!snap.hasData) return const Shimmer(child: SizedBox(height: 56));

                  final cats = snap.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int?>(
                        value: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— None —')),
                          ...cats.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text('${c.name} (${c.type})'),
                          )),
                        ],
                        onChanged: (v) async {
                          setState(() => _categoryId = v);
                          if (v != null) {
                            final kind = await _kindFromCategory(db, v);
                            if (mounted) setState(() => _manualKind = kind);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_categoryId == null)
                        SegmentedButton<TxnKind>(
                          segments: const [
                            ButtonSegment(value: TxnKind.expense, label: Text('Expense')),
                            ButtonSegment(value: TxnKind.income, label: Text('Income')),
                          ],
                          selected: {_manualKind},
                          onSelectionChanged: (set) {
                            setState(() => _manualKind = set.first);
                          },
                        ),
                    ],
                  );
                },
              ),
            ),

          // Split rows
          if (_isSplit)
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: StreamBuilder<List<Category>>(
                stream: db.categoriesDao.watchAll(),
                builder: (context, snap) {
                  if (snap.hasError) return Text('Categories load error: ${snap.error}');
                  if (!snap.hasData) return const Shimmer(child: SizedBox(height: 56));

                  final cats = snap.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Splits', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      for (int i = 0; i < _splits.length; i++) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int?>(
                                value: _splits[i].categoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: cats
                                    .map((c) => DropdownMenuItem<int?>(
                                          value: c.id,
                                          child: Text('${c.name} (${c.type})'),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _splits[i].categoryId = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _splits[i].amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: _splits.length <= 1 ? null : () => _removeSplitRow(i),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton.icon(
                        onPressed: _addSplitRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add split row'),
                      ),
                    ],
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Amount / Merchant / Note / Date
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total Amount (e.g., 12.50)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: TextField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Date: ${Formatters.date(_txnAt)}'),
                trailing: ScaleTap(
                  onTap: _pickDate,
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Change'),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            child: AnimatedButton(
              onPressed: _save,
              isLoading: _isSaving,
              icon: Icons.save,
              child: Text(_isEdit ? 'Save Changes' : 'Save Transaction'),
            ),
          ),
        ],
      ),
    );
  }
}
