part of '../app_database.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(AppDatabase db) : super(db);

  Future<List<Goal>> getAll() => select(goals).get();

  Future<int> insertOne(GoalsCompanion entry) => into(goals).insert(entry);
}