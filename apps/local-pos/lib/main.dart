import 'package:auice_pos/app/app.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.initialize();
  runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(database)], child: const AuicePosApp()));
}

