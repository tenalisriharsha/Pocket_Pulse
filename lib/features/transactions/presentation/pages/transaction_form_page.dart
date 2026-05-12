import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  final Transaction? existing;

  const TransactionFormPage({super.key, this.existing});

  @override
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  AppDatabase get db => ref.read(databaseProvider);

  late final TextEditingController amountCtrl;
  late final TextEditingController merchantCtrl;
  late final TextEditingController noteCtrl;

  String txnKind = 'expense'; // expense => negative, income => positive
  int? accountId;
  int? categoryId;
  DateTime txnDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    final ex = widget.existing;

    amountCtrl = TextEditingController(
      text: ex == null ? '' : (ex.amountCents.abs() / 100).toStringAsFixed(2),
    );
    merchantCtrl = TextEditingController(text: ex?.merchant ?? '');
    noteCtrl = TextEditingController(text: ex?.note ?? '');

    if (ex != null) {
      txnKind = ex.amountCents < 0 ? 'expense' : 'income';
      accountId = ex.accountId;
      categoryId = ex.categoryId;
      txnDate = ex.txnAt;
    }
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    merchantCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  // Uses Formatters.date from shared utils

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: txnDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => txnDate = picked);
  }

  Future<void> _save() async {
    final amtText = amountCtrl.text.trim();
    final amt = double.tryParse(amtText);

    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an account')),
      );
      return;
    }
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final centsAbs = (amt * 100).round();
    final signedCents = txnKind == 'expense' ? -centsAbs : centsAbs;
    try {
      final ex = widget.existing;

      if (ex == null) {
        await db.transactionsDao.insertOne(
          TransactionsCompanion.insert(
            accountId: accountId!,
            categoryId: categoryId == null ? const Value.absent() : Value(categoryId),
            amountCents: signedCents,
            merchant: merchantCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(merchantCtrl.text.trim()),
            note: noteCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(noteCtrl.text.trim()),
            txnAt: txnDate,
          ),
        );
      } else {
        await db.transactionsDao.updateOne(
          ex.copyWith(
            accountId: accountId!,
            categoryId: categoryId == null
                ? const Value.absent()
                : Value(categoryId),
            amountCents: signedCents,
            merchant: merchantCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(merchantCtrl.text.trim()),
            note: noteCtrl.text.trim().isEmpty
                ? const Value.absent()
                : Value(noteCtrl.text.trim()),
            txnAt: txnDate,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await db.transactionsDao.deleteById(ex.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: txnKind,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
              ],
              onChanged: (v) => setState(() => txnKind = v ?? 'expense'),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (USD)'),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<Account>>(
              stream: db.accountsDao.watchAll(),
              builder: (context, snap) {
                final accounts = snap.data ?? const <Account>[];
                return DropdownButtonFormField<int>(
                  value: accountId,
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(a.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => accountId = v),
                  decoration: const InputDecoration(labelText: 'Account'),
                );
              },
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<Category>>(
              stream: db.categoriesDao.watchAll(),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];
                return DropdownButtonFormField<int?>(
                  value: categoryId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No category'),
                    ),
                    ...cats.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => categoryId = v),
                  decoration: const InputDecoration(labelText: 'Category'),
                );
              },
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('Date: ${Formatters.date(txnDate)}'),
            ),

            const SizedBox(height: 12),
            TextField(
              controller: merchantCtrl,
              decoration: const InputDecoration(labelText: 'Merchant (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}