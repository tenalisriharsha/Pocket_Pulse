import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';
import 'package:drift/drift.dart' show Value;

import 'package:pocket_pulse/shared/animations/confetti_overlay.dart';
import 'package:pocket_pulse/shared/animations/fade_slide_in.dart';
import 'package:pocket_pulse/shared/animations/hover_card.dart';
import 'package:pocket_pulse/shared/animations/scale_tap.dart';
import 'package:pocket_pulse/shared/providers/database_provider.dart';
import 'package:pocket_pulse/shared/utils/formatters.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  Future<void> _openAccountDialog({Account? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String type = existing?.type ?? 'cash';
    final openingCtrl = TextEditingController(
      text: existing == null ? '' : (existing.openingBalanceCents / 100).toStringAsFixed(2),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Account' : 'Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('cash')),
                  DropdownMenuItem(value: 'checking', child: Text('checking')),
                  DropdownMenuItem(value: 'savings', child: Text('savings')),
                  DropdownMenuItem(value: 'credit', child: Text('credit')),
                ],
                onChanged: (v) => setState(() => type = v ?? 'cash'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: openingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Opening balance (USD)',
                  hintText: 'e.g. 1250.50',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final openingText = openingCtrl.text.trim();
    nameCtrl.dispose();
    openingCtrl.dispose();
    if (ok != true) return;
    if (name.isEmpty) return;

    final opening = double.tryParse(openingText);
    final openingCents = opening == null
        ? (existing?.openingBalanceCents ?? 0)
        : (opening * 100).round();

    final db = ref.read(databaseProvider);
    try {
      if (existing == null) {
        await db.accountsDao.insertOne(
          AccountsCompanion.insert(
            name: name,
            type: type,
            openingBalanceCents: Value(openingCents),
          ),
        );
        if (mounted) ConfettiHelper.burst(context);
      } else {
        await db.accountsDao.updateOne(
          existing.copyWith(
            name: name,
            type: type,
            openingBalanceCents: openingCents,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteAccount(Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('This will delete "${a.name}". (Transactions linked later may fail)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    final db = ref.read(databaseProvider);
    try {
      await db.accountsDao.deleteById(a.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAccountDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Account>>(
        stream: db.accountsDao.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Accounts stream error:\n${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snap.data ?? const <Account>[];

          if (rows.isEmpty) {
            return FadeSlideIn(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 48, color: cs.outline),
                    const SizedBox(height: 12),
                    Text('No accounts yet', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('Tap + to add one', style: TextStyle(color: cs.outline, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      'Total accounts: ${rows.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              final a = rows[i - 1];
              return FadeSlideIn(
                delay: Duration(milliseconds: (i % 8) * 30),
                child: HoverCard(
                  onTap: () => _openAccountDialog(existing: a),
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.account_balance,
                            color: cs.onPrimaryContainer, size: 18),
                      ),
                      title: Text(a.name),
                      subtitle: Text(
                          '${a.type} • ${a.currency} • opening ${Formatters.money(a.openingBalanceCents)}'),
                      trailing: ScaleTap(
                        onTap: () => _deleteAccount(a),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteAccount(a),
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
    );
  }
}
