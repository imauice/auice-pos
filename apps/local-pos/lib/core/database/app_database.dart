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
  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  IntColumn get entityVersion => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Branches extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get timezone => text()();
  TextColumn get currency => text()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  IntColumn get catalogVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  IntColumn get catalogVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get baseUnitId => text().nullable()();
  BoolColumn get trackStock => boolean()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  IntColumn get catalogVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductUnits extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get productId => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get unitCategory => text()();
  BoolColumn get isBaseUnit => boolean()();
  IntColumn get conversionNumerator => integer()();
  IntColumn get conversionDenominator => integer()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get allowSale => boolean()();
  BoolColumn get allowPurchase => boolean()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  IntColumn get catalogVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductPrices extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get productId => text()();
  TextColumn get productUnitId => text()();
  IntColumn get priceMinor => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  BoolColumn get active => boolean()();
  IntColumn get version => integer()();
  IntColumn get catalogVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppMetadata,
    SyncOutbox,
    Branches,
    Categories,
    Products,
    ProductUnits,
    ProductPrices,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX sync_outbox_pending_created_idx ON sync_outbox(status, created_at)',
      );
      await _createCatalogIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(syncOutbox);
        await customStatement(
          'CREATE INDEX sync_outbox_pending_created_idx ON sync_outbox(status, created_at)',
        );
      }
      if (from < 3) {
        await m.createTable(branches);
        await m.createTable(categories);
        await m.createTable(products);
        await m.createTable(productUnits);
        await m.createTable(productPrices);
        await _createCatalogIndexes();
      }
    },
  );
  Future<void> _createCatalogIndexes() async {
    await customStatement(
      'CREATE INDEX products_branch_sku_idx ON products(branch_id, sku)',
    );
    await customStatement(
      'CREATE INDEX products_branch_name_idx ON products(branch_id, name)',
    );
    await customStatement(
      'CREATE INDEX product_units_branch_barcode_idx ON product_units(branch_id, barcode)',
    );
    await customStatement(
      'CREATE INDEX product_units_product_idx ON product_units(product_id)',
    );
    await customStatement(
      'CREATE INDEX product_prices_unit_effective_idx ON product_prices(product_unit_id, effective_from)',
    );
  }

  Future<void> initialize() async {
    await into(appMetadata).insertOnConflictUpdate(
      AppMetadataCompanion.insert(
        key: 'database_status',
        value: 'ready',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> insertOutboxEvent(SyncOutboxCompanion event) =>
      transaction(() async {
        await into(syncOutbox).insert(event);
      });
  Future<List<SyncOutboxData>> listPendingEvents() =>
      (select(syncOutbox)
            ..where((row) => row.status.equals('pending'))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();
  Future<void> markOutboxProcessing(String id, DateTime attemptedAt) =>
      transaction(
        () => (update(syncOutbox)..where((row) => row.id.equals(id))).write(
          SyncOutboxCompanion(
            status: const Value('processing'),
            lastAttemptAt: Value(attemptedAt.toUtc()),
          ),
        ),
      );
  Future<void> markOutboxSynced(String id, DateTime syncedAt) => transaction(
    () => (update(syncOutbox)..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value('synced'),
        syncedAt: Value(syncedAt.toUtc()),
        lastError: const Value(null),
      ),
    ),
  );
  Future<void> markOutboxFailed(
    String id,
    String error,
    DateTime attemptedAt,
  ) => transaction(() async {
    final current = await (select(
      syncOutbox,
    )..where((row) => row.id.equals(id))).getSingle();
    await (update(syncOutbox)..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value('pending'),
        retryCount: Value(current.retryCount + 1),
        lastAttemptAt: Value(attemptedAt.toUtc()),
        lastError: Value(error),
      ),
    );
  });
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(directory.path, 'auice_pos.sqlite')),
  );
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
