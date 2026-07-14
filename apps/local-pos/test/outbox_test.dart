import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

SyncOutboxCompanion event(String id, DateTime createdAt) =>
    SyncOutboxCompanion.insert(
      id: id,
      branchId: 'branch',
      deviceId: 'device',
      entityType: 'product',
      entityId: 'entity',
      operation: 'create',
      entityVersion: 1,
      payloadJson: '{"name":"Beer"}',
      occurredAt: createdAt,
      createdAt: createdAt,
    );
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('insert and pending events are creation ordered', () async {
    final later = DateTime.utc(2026, 1, 2), earlier = DateTime.utc(2026, 1, 1);
    await db.insertOutboxEvent(event('later', later));
    await db.insertOutboxEvent(event('earlier', earlier));
    expect((await db.listPendingEvents()).map((e) => e.id), [
      'earlier',
      'later',
    ]);
  });
  test(
    'retryable failure returns to pending, remains selectable, then syncs',
    () async {
      final now = DateTime.utc(2026);
      await db.insertOutboxEvent(event('one', now));
      await db.markOutboxProcessing('one', now);
      expect((await db.select(db.syncOutbox).getSingle()).status, 'processing');
      await db.markOutboxFailed('one', 'offline', now);
      var row = await db.select(db.syncOutbox).getSingle();
      expect(row.status, 'pending');
      expect(row.retryCount, 1);
      expect(row.lastError, 'offline');
      expect((await db.listPendingEvents()).single.id, 'one');
      await db.markOutboxSynced('one', now);
      row = await db.select(db.syncOutbox).getSingle();
      expect(row.status, 'synced');
      expect(row.syncedAt?.toUtc(), now);
    },
  );
  test('v1 migration preserves app_metadata', () async {
    await db.close();
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE app_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
    );
    raw.execute("INSERT INTO app_metadata VALUES ('proof','ready',0)");
    raw.execute('PRAGMA user_version = 1');
    final migrated = AppDatabase.forTesting(NativeDatabase.opened(raw));
    expect(
      (await migrated.select(migrated.appMetadata).getSingle()).value,
      'ready',
    );
    await migrated.insertOutboxEvent(event('new', DateTime.utc(2026)));
    expect((await migrated.listPendingEvents()).single.id, 'new');
    await migrated.close();
  });
  test('v2 to v3 migration preserves app_metadata and sync_outbox', () async {
    await db.close();
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE app_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE sync_outbox (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, device_id TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, entity_version INTEGER NOT NULL, payload_json TEXT NOT NULL, occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', retry_count INTEGER NOT NULL DEFAULT 0, last_attempt_at INTEGER NULL, last_error TEXT NULL, synced_at INTEGER NULL)',
    );
    raw.execute("INSERT INTO app_metadata VALUES ('proof','ready',0)");
    raw.execute(
      "INSERT INTO sync_outbox (id,branch_id,device_id,entity_type,entity_id,operation,entity_version,payload_json,occurred_at,created_at) VALUES ('event','b','d','product','p','create',1,'{}',0,0)",
    );
    raw.execute('PRAGMA user_version = 2');
    final migrated = AppDatabase.forTesting(NativeDatabase.opened(raw));
    expect(
      (await migrated.select(migrated.appMetadata).getSingle()).value,
      'ready',
    );
    expect(
      (await migrated.select(migrated.syncOutbox).getSingle()).id,
      'event',
    );
    expect(await migrated.select(migrated.products).get(), isEmpty);
    await migrated.close();
  });
  test('v3 to v8 migration preserves data and creates sale and shift schema', () async {
    await db.close();
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE app_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE sync_outbox (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, device_id TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, entity_version INTEGER NOT NULL, payload_json TEXT NOT NULL, occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT \'pending\', retry_count INTEGER NOT NULL DEFAULT 0, last_attempt_at INTEGER NULL, last_error TEXT NULL, synced_at INTEGER NULL)',
    );
    raw.execute(
      'CREATE TABLE products (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, category_id TEXT NULL, sku TEXT NULL, name TEXT NOT NULL, description TEXT NULL, base_unit_id TEXT NULL, track_stock INTEGER NOT NULL, active INTEGER NOT NULL, version INTEGER NOT NULL, catalog_version INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL)',
    );
    raw.execute("INSERT INTO app_metadata VALUES ('proof','ready',0)");
    raw.execute(
      "INSERT INTO sync_outbox (id,branch_id,device_id,entity_type,entity_id,operation,entity_version,payload_json,occurred_at,created_at) VALUES ('pending','b','d','product','p','create',1,'{}',0,0)",
    );
    raw.execute(
      "INSERT INTO products (id,branch_id,sku,name,track_stock,active,version,catalog_version,updated_at) VALUES ('p','b','SKU','Existing',0,1,1,1,0)",
    );
    raw.execute('PRAGMA user_version = 3');
    final migrated = AppDatabase.forTesting(NativeDatabase.opened(raw));
    expect(
      (await migrated.select(migrated.appMetadata).getSingle()).value,
      'ready',
    );
    expect(
      (await migrated.select(migrated.syncOutbox).getSingle()).id,
      'pending',
    );
    expect(
      (await migrated.select(migrated.products).getSingle()).name,
      'Existing',
    );
    expect(
      (await migrated.select(migrated.products).getSingle()).baseQuantityScale,
      1,
    );
    expect(await migrated.select(migrated.sales).get(), isEmpty);
    expect(await migrated.select(migrated.cashMovements).get(), isEmpty);
    final shiftColumns = raw
        .select('PRAGMA table_info(shifts)')
        .map((row) => row['name'])
        .toSet();
    expect(
      shiftColumns,
      containsAll({
        'cash_sales_minor',
        'cash_in_minor',
        'cash_out_minor',
        'sales_count',
        'cash_sales_count',
        'gross_sales_minor',
        'deleted_at',
      }),
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='sales_sold_at_idx'",
      ),
      isNotEmpty,
    );
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='cash_movements_shift_occurred_idx'",
      ),
      isNotEmpty,
    );
    await migrated.close();
  });

  test('v6 to v8 migration defaults summaries and adds inventory fields', () async {
    await db.close();
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE shifts (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, device_id TEXT NOT NULL, status TEXT NOT NULL, opened_at INTEGER NOT NULL, closed_at INTEGER NULL, opening_cash_minor INTEGER NOT NULL, cash_sales_minor INTEGER NOT NULL DEFAULT 0, cash_in_minor INTEGER NOT NULL DEFAULT 0, cash_out_minor INTEGER NOT NULL DEFAULT 0, closing_cash_minor INTEGER NULL, expected_cash_minor INTEGER NULL, cash_difference_minor INTEGER NULL, currency TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL, deleted_at INTEGER NULL)',
    );
    raw.execute(
      'CREATE TABLE products (id TEXT NOT NULL PRIMARY KEY, base_quantity_scale INTEGER NOT NULL DEFAULT 1)',
    );
    raw.execute(
      'CREATE TABLE stock_movements (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, device_id TEXT NOT NULL, product_id TEXT NOT NULL, type TEXT NOT NULL, source_unit_id TEXT NOT NULL, source_unit_code_snapshot TEXT NOT NULL, source_unit_name_snapshot TEXT NOT NULL, source_quantity_minor INTEGER NOT NULL, source_quantity_scale INTEGER NOT NULL, conversion_numerator_snapshot INTEGER NOT NULL, conversion_denominator_snapshot INTEGER NOT NULL, base_quantity_minor INTEGER NOT NULL, base_quantity_scale INTEGER NOT NULL, reference_type TEXT NOT NULL, reference_id TEXT NOT NULL, occurred_at INTEGER NOT NULL, note TEXT NULL, created_at INTEGER NOT NULL, version INTEGER NOT NULL)',
    );
    raw.execute(
      'CREATE TABLE sales (id TEXT NOT NULL PRIMARY KEY, branch_id TEXT NOT NULL, device_id TEXT NOT NULL, shift_id TEXT NOT NULL, receipt_number TEXT NOT NULL UNIQUE, status TEXT NOT NULL, currency TEXT NOT NULL, subtotal_minor INTEGER NOT NULL, discount_minor INTEGER NOT NULL, tax_minor INTEGER NOT NULL, total_minor INTEGER NOT NULL, paid_minor INTEGER NOT NULL, change_minor INTEGER NOT NULL, item_count INTEGER NOT NULL, sold_at INTEGER NOT NULL, voided_at INTEGER NULL, void_reason TEXT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL, deleted_at INTEGER NULL)',
    );
    raw.execute(
      "INSERT INTO shifts (id,branch_id,device_id,status,opened_at,opening_cash_minor,currency,created_at,updated_at,version) VALUES ('shift','branch','device','closed',0,100,'THB',0,0,2)",
    );
    raw.execute(
      "INSERT INTO stock_movements VALUES ('movement','branch','device','product','sale','unit','each','Each',1,1,1,1,-1,1,'sale','sale',0,NULL,0,1)",
    );
    raw.execute(
      "INSERT INTO sales (id,branch_id,device_id,shift_id,receipt_number,status,currency,subtotal_minor,discount_minor,tax_minor,total_minor,paid_minor,change_minor,item_count,sold_at,created_at,updated_at,version) VALUES ('sale','branch','device','shift','R-1','completed','THB',100,0,0,100,100,0,1,0,0,0,1)",
    );
    raw.execute('PRAGMA user_version = 6');
    final migrated = AppDatabase.forTesting(NativeDatabase.opened(raw));
    final shift = await migrated.select(migrated.shifts).getSingle();
    expect(shift.id, 'shift');
    expect(shift.salesCount, 0);
    expect(shift.cashSalesCount, 0);
    expect(shift.grossSalesMinor, 0);
    expect((await migrated.select(migrated.sales).getSingle()).id, 'sale');
    expect(
      (await migrated.select(migrated.stockMovements).getSingle()).id,
      'movement',
    );
    expect(
      raw.select('PRAGMA table_info(products)').map((row) => row['name']),
      containsAll(['low_stock_threshold_minor', 'low_stock_threshold_scale']),
    );
    expect(
      raw
          .select('PRAGMA table_info(stock_movements)')
          .map((row) => row['name']),
      contains('reason_code'),
    );
    await migrated.close();
  });
}
