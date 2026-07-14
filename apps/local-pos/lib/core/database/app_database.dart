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
  IntColumn get baseQuantityScale => integer().withDefault(const Constant(1))();
  IntColumn get lowStockThresholdMinor => integer().nullable()();
  IntColumn get lowStockThresholdScale => integer().nullable()();
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

class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get status => text()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingCashMinor => integer()();
  IntColumn get cashSalesMinor => integer().withDefault(const Constant(0))();
  IntColumn get cashInMinor => integer().withDefault(const Constant(0))();
  IntColumn get cashOutMinor => integer().withDefault(const Constant(0))();
  IntColumn get salesCount => integer().withDefault(const Constant(0))();
  IntColumn get cashSalesCount => integer().withDefault(const Constant(0))();
  IntColumn get grossSalesMinor => integer().withDefault(const Constant(0))();
  IntColumn get closingCashMinor => integer().nullable()();
  IntColumn get expectedCashMinor => integer().nullable()();
  IntColumn get cashDifferenceMinor => integer().nullable()();
  TextColumn get currency => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CashMovements extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get shiftId => text()();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get reasonCode => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get shiftId => text()();
  TextColumn get receiptNumber => text().unique()();
  TextColumn get status => text()();
  TextColumn get currency => text()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer()();
  IntColumn get taxMinor => integer()();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer()();
  IntColumn get changeMinor => integer()();
  IntColumn get itemCount => integer()();
  DateTimeColumn get soldAt => dateTime()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get productId => text()();
  TextColumn get productUnitId => text()();
  TextColumn get productNameSnapshot => text()();
  TextColumn get skuSnapshot => text().nullable()();
  TextColumn get unitCodeSnapshot => text()();
  TextColumn get unitNameSnapshot => text()();
  TextColumn get barcodeSnapshot => text().nullable()();
  IntColumn get quantityMinor => integer()();
  IntColumn get quantityScale => integer()();
  IntColumn get conversionNumeratorSnapshot => integer()();
  IntColumn get conversionDenominatorSnapshot => integer()();
  IntColumn get baseQuantityMinor => integer()();
  IntColumn get baseQuantityScale => integer()();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer()();
  IntColumn get taxMinor => integer()();
  IntColumn get totalMinor => integer()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get method => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get branchId => text()();
  TextColumn get deviceId => text()();
  TextColumn get productId => text()();
  TextColumn get type => text()();
  TextColumn get sourceUnitId => text()();
  TextColumn get sourceUnitCodeSnapshot => text()();
  TextColumn get sourceUnitNameSnapshot => text()();
  IntColumn get sourceQuantityMinor => integer()();
  IntColumn get sourceQuantityScale => integer()();
  IntColumn get conversionNumeratorSnapshot => integer()();
  IntColumn get conversionDenominatorSnapshot => integer()();
  IntColumn get baseQuantityMinor => integer()();
  IntColumn get baseQuantityScale => integer()();
  TextColumn get referenceType => text()();
  TextColumn get referenceId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get reasonCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReceiptSequences extends Table {
  TextColumn get deviceId => text()();
  TextColumn get localDate => text()();
  IntColumn get nextValue => integer()();
  @override
  Set<Column<Object>> get primaryKey => {deviceId, localDate};
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
    Shifts,
    CashMovements,
    Sales,
    SaleItems,
    Payments,
    StockMovements,
    ReceiptSequences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 8;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX sync_outbox_pending_created_idx ON sync_outbox(status, created_at)',
      );
      await _createCatalogIndexes();
      await _createSaleIndexes();
      await _createShiftIndexes();
      await _createInventoryIndexes();
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
      if (from < 4) {
        await m.createTable(shifts);
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.createTable(payments);
        await m.createTable(stockMovements);
        await m.createTable(receiptSequences);
        await _createSaleIndexes();
      }
      if (from >= 3 && from < 5) {
        await m.addColumn(products, products.baseQuantityScale);
      }
      if (from >= 4 && from < 6) {
        await m.addColumn(shifts, shifts.cashSalesMinor);
        await m.addColumn(shifts, shifts.cashInMinor);
        await m.addColumn(shifts, shifts.cashOutMinor);
        await m.addColumn(shifts, shifts.deletedAt);
      }
      if (from >= 4 && from < 7) {
        await m.addColumn(shifts, shifts.salesCount);
        await m.addColumn(shifts, shifts.cashSalesCount);
        await m.addColumn(shifts, shifts.grossSalesMinor);
      }
      if (from >= 3 && from < 8) {
        await m.addColumn(products, products.lowStockThresholdMinor);
        await m.addColumn(products, products.lowStockThresholdScale);
      }
      if (from >= 4 && from < 8) {
        await m.addColumn(stockMovements, stockMovements.reasonCode);
      }
      if (from < 6) {
        await m.createTable(cashMovements);
        await _createShiftIndexes();
      }
      if (from < 8) {
        await _createInventoryIndexes();
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

  Future<void> _createSaleIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX shifts_one_open_device_idx ON shifts(device_id) WHERE status = 'open'",
    );
    await customStatement(
      'CREATE INDEX sales_sold_at_idx ON sales(sold_at DESC)',
    );
    await customStatement(
      'CREATE INDEX sale_items_sale_idx ON sale_items(sale_id)',
    );
    await customStatement(
      'CREATE INDEX payments_sale_idx ON payments(sale_id)',
    );
    await customStatement(
      'CREATE INDEX stock_movements_reference_idx ON stock_movements(reference_type, reference_id)',
    );
  }

  Future<void> _createShiftIndexes() async {
    await customStatement(
      'CREATE INDEX shifts_branch_opened_idx ON shifts(branch_id, opened_at DESC)',
    );
    await customStatement(
      'CREATE INDEX sales_shift_status_idx ON sales(shift_id, status)',
    );
    await customStatement(
      'CREATE INDEX payments_sale_method_idx ON payments(sale_id, method)',
    );
    await customStatement(
      'CREATE INDEX cash_movements_shift_occurred_idx ON cash_movements(shift_id, occurred_at)',
    );
    await customStatement(
      'CREATE INDEX cash_movements_branch_device_idx ON cash_movements(branch_id, device_id)',
    );
  }

  Future<void> _createInventoryIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS stock_movements_branch_product_occurred_idx ON stock_movements(branch_id, product_id, occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS stock_movements_product_type_idx ON stock_movements(product_id, type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS stock_movements_branch_occurred_idx ON stock_movements(branch_id, occurred_at DESC)',
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
