import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_db/app_database.dart';
import '../data/local_db/seed/seed_runner.dart';
import '../shared/providers/database_provider.dart';
import 'package:pocket_pulse/shared/services/notification_service.dart';

Future<ProviderContainer> bootstrap() async {
  final db = AppDatabase.instance;

  final seeder = SeedRunner(db);
  await seeder.seedDefaultCategoriesIfEmpty();

  // Init plugin only (no permission prompt here)
  await NotificationService.instance.ensureInitialized();

  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
  );
}