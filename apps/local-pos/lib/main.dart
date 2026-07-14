import 'package:auice_pos/app/app.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auice_pos/core/catalog/catalog_gateway.dart';
import 'package:auice_pos/core/catalog/catalog_import_service.dart';
import 'package:auice_pos/features/startup/catalog_startup_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.initialize();
  final catalogCoordinator = CatalogStartupCoordinator(
    db: database,
    gateway: DioCatalogGateway(),
    importer: CatalogImportService(database),
  );
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        catalogStartupCoordinatorProvider.overrideWithValue(catalogCoordinator),
      ],
      child: const AuicePosApp(),
    ),
  );
}
