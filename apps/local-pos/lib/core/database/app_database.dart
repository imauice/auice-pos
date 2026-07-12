import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
part 'app_database.g.dart';

class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [AppMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);
  @override int get schemaVersion => 1;
  Future<void> initialize() async {
    await into(appMetadata).insertOnConflictUpdate(AppMetadataCompanion.insert(key: 'database_status', value: 'ready', updatedAt: DateTime.now().toUtc()));
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(File(p.join(directory.path, 'auice_pos.sqlite')));
});

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('Database must be initialized before app startup'));

