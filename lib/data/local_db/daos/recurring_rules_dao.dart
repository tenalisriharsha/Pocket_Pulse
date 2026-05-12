part of '../app_database.dart';

/// UI-friendly row: recurring rule + account + optional category.
class RecurringRow {
  final RecurringRule rule;
  final Account account;
  final Category? category;

  RecurringRow({
    required this.rule,
    required this.account,
    required this.category,
  });
}

@DriftAccessor(tables: [RecurringRules, Accounts, Categories, Transactions])
class RecurringRulesDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringRulesDaoMixin {
  RecurringRulesDao(AppDatabase db) : super(db);

  Future<List<RecurringRule>> getAll() => select(recurringRules).get();

  Stream<List<RecurringRule>> watchActive() =>
      (select(recurringRules)..where((t) => t.isActive.equals(true))).watch();

  /// Upcoming (includes overdue): active rules whose nextDueDate <= now + daysAhead.
  Stream<List<RecurringRow>> watchUpcoming({required int daysAhead}) {
    final r = recurringRules;
    final a = accounts;
    final c = categories;

    final end = DateTime.now().add(Duration(days: daysAhead));

    final query = select(r).join([
      innerJoin(a, a.id.equalsExp(r.accountId)),
      leftOuterJoin(c, c.id.equalsExp(r.categoryId)),
    ]);

    query.where(r.isActive.equals(true));
    query.where(r.nextDueDate.isSmallerOrEqualValue(end));
    query.orderBy([OrderingTerm.asc(r.nextDueDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return RecurringRow(
          rule: row.readTable(r),
          account: row.readTable(a),
          category: row.readTableOrNull(c),
        );
      }).toList();
    });
  }

  Future<int> insertRule(RecurringRulesCompanion entry) =>
      into(recurringRules).insert(entry);

  Future<bool> updateRule(RecurringRule rule) =>
      update(recurringRules).replace(rule);

  Future<void> setActive(int ruleId, bool isActive) async {
    await (update(recurringRules)..where((t) => t.id.equals(ruleId))).write(
      RecurringRulesCompanion(isActive: Value(isActive)),
    );
  }

  Future<RecurringRule?> getById(int id) {
    return (select(recurringRules)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Mark as paid:
  /// - sets lastPaidAt = now
  /// - advances nextDueDate by (frequency, interval)
  /// - optionally creates a Transaction (recommended)
  Future<void> markAsPaid(
    int ruleId, {
    bool createTransaction = true,
  }) async {
    await transaction(() async {
      final rule = await (select(recurringRules)..where((t) => t.id.equals(ruleId)))
          .getSingle();

      final now = DateTime.now();
      // Advance at least one period from the *current* nextDueDate.
      // If the rule is overdue by multiple periods, keep advancing until it's after today
      // so the item doesn't immediately remain overdue.
      final today = DateTime(now.year, now.month, now.day);
      var next = _advanceDueDate(rule.nextDueDate, rule.frequency, rule.interval);
      while (!next.isAfter(today)) {
        next = _advanceDueDate(next, rule.frequency, rule.interval);
      }

      await (update(recurringRules)..where((t) => t.id.equals(ruleId))).write(
        RecurringRulesCompanion(
          lastPaidAt: Value(now),
          nextDueDate: Value(next),
        ),
      );

      if (!createTransaction) return;

      // Convention in your app:
      // expense amounts are stored NEGATIVE, income POSITIVE.
      final isExpense = rule.type.toLowerCase() == 'expense';
      final signedAmount = isExpense ? -rule.amountCents.abs() : rule.amountCents.abs();

      await into(attachedDatabase.transactions).insert(
        TransactionsCompanion.insert(
          accountId: rule.accountId,
          categoryId: rule.categoryId == null
              ? const Value.absent()
              : Value(rule.categoryId!),
          amountCents: signedAmount,
          merchant: Value(rule.name),
          note: const Value('Recurring payment'),
          txnAt: now,
        ),
      );
    });
  }

  // ---------------- Due date math ----------------

  DateTime _advanceDueDate(DateTime from, String frequency, int interval) {
    final f = frequency.toLowerCase().trim();
    final step = interval <= 0 ? 1 : interval;

    switch (f) {
      case 'daily':
        return from.add(Duration(days: step));
      case 'weekly':
        return from.add(Duration(days: 7 * step));
      case 'yearly':
        // Clamp day for edge cases (e.g., Feb 29 on non-leap years)
        final lastDay = DateTime(from.year + step, from.month + 1, 0).day;
        final day = from.day <= lastDay ? from.day : lastDay;
        return DateTime(from.year + step, from.month, day, from.hour, from.minute, from.second);
      case 'monthly':
      default:
        return _addMonthsClamped(from, step);
    }
  }

  DateTime _addMonthsClamped(DateTime d, int monthsToAdd) {
    // Keep the same day-of-month when possible; clamp to last day otherwise.
    final targetMonthIndex = (d.month - 1) + monthsToAdd;
    final newYear = d.year + (targetMonthIndex ~/ 12);
    final newMonth = (targetMonthIndex % 12) + 1;

    final lastDay = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = d.day <= lastDay ? d.day : lastDay;

    return DateTime(newYear, newMonth, newDay, d.hour, d.minute, d.second);
  }
}