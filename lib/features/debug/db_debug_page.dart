import 'package:flutter/material.dart';
import 'package:pocket_pulse/data/local_db/app_database.dart';

class DbDebugPage extends StatefulWidget {
  const DbDebugPage({super.key});

  @override
  State<DbDebugPage> createState() => _DbDebugPageState();
}

class _DbDebugPageState extends State<DbDebugPage>
    with SingleTickerProviderStateMixin {
  late final AppDatabase db;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    db = AppDatabase.instance;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addCategoryDialog() async {
    final nameCtrl = TextEditingController();
    String type = 'expense';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
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
                DropdownMenuItem(value: 'expense', child: Text('expense')),
                DropdownMenuItem(value: 'income', child: Text('income')),
              ],
              onChanged: (v) => type = v ?? 'expense',
              decoration: const InputDecoration(labelText: 'Type'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) {
      nameCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (name.isEmpty) return;

    await db.categoriesDao.insertOne(
      CategoriesCompanion.insert(name: name, type: type),
    );
  }

  Future<void> _addAccountDialog() async {
    final nameCtrl = TextEditingController();
    String type = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Account'),
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
              onChanged: (v) => type = v ?? 'cash',
              decoration: const InputDecoration(labelText: 'Type'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) {
      nameCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (name.isEmpty) return;

    try {
      final id = await db.accountsDao.insertOne(
        AccountsCompanion.insert(name: name, type: type),
      );

      final countRow =
          await db.customSelect('SELECT COUNT(*) AS c FROM accounts;')
              .getSingle();

      debugPrint(
        'Inserted account id=$id, accounts count=${countRow.data['c']}',
      );
    } catch (e, st) {
      debugPrint('Insert account failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insert failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB Debug'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Accounts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_tabController.index == 0) {
            await _addCategoryDialog();
          } else {
            await _addAccountDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ---------------- Categories ----------------
          StreamBuilder<List<Category>>(
            stream: db.categoriesDao.watchAll(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Categories stream error:\n${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rows = snap.data ?? const <Category>[];
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Total categories: ${rows.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }

                  final c = rows[i - 1];
                  return ListTile(
                    title: Text(c.name),
                    subtitle: Text(c.type),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await db.categoriesDao.deleteById(c.id);
                      },
                    ),
                  );
                },
              );
            },
          ),

          // ---------------- Accounts ----------------
          StreamBuilder<List<Account>>(
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

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Total accounts: ${rows.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }

                  final a = rows[i - 1];
                  return ListTile(
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.type} • ${a.currency} • opening=${a.openingBalanceCents}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await db.accountsDao.deleteById(a.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}