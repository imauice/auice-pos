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
}
