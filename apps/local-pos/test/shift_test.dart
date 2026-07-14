import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

final at = DateTime.utc(2026, 7, 15, 8);
Future<void> configureShift(AppDatabase db, {String device = 'device'}) async {
  if (await db.select(db.branches).getSingleOrNull() == null) {
    await db
        .into(db.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch',
            code: 'BKK',
            name: 'Bangkok',
            timezone: 'Asia/Bangkok',
            currency: 'THB',
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: at,
          ),
        );
  }
  await db
      .into(db.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: 'device_id',
          value: device,
          updatedAt: at,
        ),
      );
  await db
      .into(db.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: 'registered_branch_id',
          value: 'branch',
          updatedAt: at,
        ),
      );
  await db
      .into(db.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: 'device_active',
          value: 'true',
          updatedAt: at,
        ),
      );
}

Future<void> addCashSale(
  AppDatabase db,
  Shift shift, {
  required String id,
  required int total,
  required int paid,
  required int change,
}) async {
  await db
      .into(db.sales)
      .insert(
        SalesCompanion.insert(
          id: id,
          branchId: shift.branchId,
          deviceId: shift.deviceId,
          shiftId: shift.id,
          receiptNumber: 'R-$id',
          status: 'completed',
          currency: 'THB',
          subtotalMinor: total,
          discountMinor: 0,
          taxMinor: 0,
          totalMinor: total,
          paidMinor: paid,
          changeMinor: change,
          itemCount: 1,
          soldAt: at,
          createdAt: at,
          updatedAt: at,
          version: 1,
        ),
      );
  await db
      .into(db.payments)
      .insert(
        PaymentsCompanion.insert(
          id: 'pay-$id',
          saleId: id,
          branchId: shift.branchId,
          deviceId: shift.deviceId,
          method: 'cash',
          amountMinor: paid,
          currency: 'THB',
          paidAt: at,
          createdAt: at,
        ),
      );
}

Future<void> addOutbox(
  AppDatabase db, {
  required String id,
  required String entityType,
  required String entityId,
  String status = 'pending',
}) => db
    .into(db.syncOutbox)
    .insert(
      SyncOutboxCompanion.insert(
        id: id,
        branchId: 'branch',
        deviceId: 'device',
        entityType: entityType,
        entityId: entityId,
        operation: 'append',
        entityVersion: 1,
        payloadJson: '{}',
        occurredAt: at,
        createdAt: at,
        status: Value(status),
      ),
    );

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await configureShift(db);
  });
  tearDown(() => db.close());

  test('configuration selects only the registered active branch', () async {
    await db
        .into(db.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch-2',
            code: 'CNX',
            name: 'Chiang Mai',
            timezone: 'Asia/Bangkok',
            currency: 'THB',
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: at,
          ),
        );
    await (db.update(db.appMetadata)
          ..where((row) => row.key.equals('registered_branch_id')))
        .write(const AppMetadataCompanion(value: Value('branch-2')));

    final configuration = await loadShiftConfiguration(db);
    expect(configuration.status, ShiftConfigurationStatus.ready);
    expect(configuration.branch?.id, 'branch-2');
    expect(configuration.deviceId, 'device');
  });

  test('configuration reports each missing or inactive setup state', () async {
    await (db.delete(
      db.appMetadata,
    )..where((row) => row.key.equals('device_id'))).go();
    expect(
      (await loadShiftConfiguration(db)).status,
      ShiftConfigurationStatus.missingDeviceId,
    );
    await configureShift(db);
    await (db.delete(
      db.appMetadata,
    )..where((row) => row.key.equals('registered_branch_id'))).go();
    expect(
      (await loadShiftConfiguration(db)).status,
      ShiftConfigurationStatus.missingRegisteredBranchId,
    );
    await configureShift(db);
    await (db.update(db.appMetadata)
          ..where((row) => row.key.equals('device_active')))
        .write(const AppMetadataCompanion(value: Value('false')));
    expect(
      (await loadShiftConfiguration(db)).status,
      ShiftConfigurationStatus.inactiveDevice,
    );
    await configureShift(db);
    await (db.update(db.branches)..where((row) => row.id.equals('branch')))
        .write(const BranchesCompanion(active: Value(false)));
    expect(
      (await loadShiftConfiguration(db)).status,
      ShiftConfigurationStatus.invalidRegisteredBranch,
    );
  });

  test(
    'opens zero and positive cash shifts and rejects invalid or duplicate opens',
    () async {
      final service = OpenShiftService(db);
      final first = await service.open(
        branchId: 'branch',
        deviceId: 'device',
        openingCashMinor: 0,
        openedAt: at,
      );
      expect(first.openingCashMinor, 0);
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
      await expectLater(
        service.open(
          branchId: 'branch',
          deviceId: 'device',
          openingCashMinor: 10000,
        ),
        throwsA(isA<ShiftException>()),
      );
      await expectLater(
        service.open(
          branchId: 'branch',
          deviceId: 'device',
          openingCashMinor: -1,
        ),
        throwsA(isA<ShiftException>()),
      );
      await (db.update(db.shifts)..where((s) => s.id.equals(first.id))).write(
        const ShiftsCompanion(status: Value('closed')),
      );
      expect(
        (await service.open(
          branchId: 'branch',
          deviceId: 'device',
          openingCashMinor: 10000,
        )).openingCashMinor,
        10000,
      );
    },
  );

  test(
    'different devices can own separate open shifts and mismatch is rejected',
    () async {
      final service = OpenShiftService(db);
      await service.open(
        branchId: 'branch',
        deviceId: 'device',
        openingCashMinor: 0,
      );
      await configureShift(db, device: 'device-2');
      await service.open(
        branchId: 'branch',
        deviceId: 'device-2',
        openingCashMinor: 0,
      );
      expect(await db.select(db.shifts).get(), hasLength(2));
      await expectLater(
        service.open(
          branchId: 'branch',
          deviceId: 'wrong',
          openingCashMinor: 0,
        ),
        throwsA(isA<ShiftException>()),
      );
    },
  );

  test('open outbox failure rolls back shift creation', () async {
    final service = OpenShiftService(
      db,
      failureHook: (_) => throw StateError('forced'),
    );
    await expectLater(
      service.open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0),
      throwsA(isA<ShiftException>()),
    );
    expect(await db.select(db.shifts).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });

  test(
    'summary uses retained cash, multiple sales, and cash movements',
    () async {
      final shift = await OpenShiftService(db).open(
        branchId: 'branch',
        deviceId: 'device',
        openingCashMinor: 100000,
        openedAt: at,
      );
      await addCashSale(
        db,
        shift,
        id: 'sale1',
        total: 19500,
        paid: 20000,
        change: 500,
      );
      await addCashSale(
        db,
        shift,
        id: 'sale2',
        total: 144000,
        paid: 150000,
        change: 6000,
      );
      final cash = CashMovementService(db);
      await cash.record(
        shiftId: shift.id,
        branchId: 'branch',
        deviceId: 'device',
        type: 'cash_in',
        amountMinor: 50000,
        reasonCode: 'petty_cash_in',
      );
      await cash.record(
        shiftId: shift.id,
        branchId: 'branch',
        deviceId: 'device',
        type: 'cash_out',
        amountMinor: 20000,
        reasonCode: 'cash_drop',
      );
      final summary = await ShiftSummaryService(
        db,
        ShiftRepository(db),
      ).get(shift.id);
      expect(summary.salesCount, 2);
      expect(summary.cashSalesCount, 2);
      expect(summary.cashSalesMinor, 163500);
      expect(summary.grossSalesMinor, 163500);
      expect(summary.expectedCashMinor, 293500);

      await (db.update(db.sales)..where((sale) => sale.id.equals('sale2')))
          .write(const SalesCompanion(status: Value('voided')));
      final changedOpenSummary = await ShiftSummaryService(
        db,
        ShiftRepository(db),
      ).get(shift.id);
      expect(changedOpenSummary.salesCount, 1);
      expect(changedOpenSummary.grossSalesMinor, 19500);
    },
  );

  test(
    'cash movements validate amount, shift state, relation, and rollback outbox',
    () async {
      final shift = await OpenShiftService(
        db,
      ).open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0);
      final service = CashMovementService(db);
      for (final amount in [0, -1]) {
        await expectLater(
          service.record(
            shiftId: shift.id,
            branchId: 'branch',
            deviceId: 'device',
            type: 'cash_in',
            amountMinor: amount,
            reasonCode: 'other',
          ),
          throwsA(isA<ShiftException>()),
        );
      }
      await expectLater(
        service.record(
          shiftId: shift.id,
          branchId: 'other',
          deviceId: 'device',
          type: 'cash_in',
          amountMinor: 1,
          reasonCode: 'other',
        ),
        throwsA(isA<ShiftException>()),
      );
      final failing = CashMovementService(
        db,
        failureHook: (_) => throw StateError('forced'),
      );
      await expectLater(
        failing.record(
          shiftId: shift.id,
          branchId: 'branch',
          deviceId: 'device',
          type: 'cash_in',
          amountMinor: 1,
          reasonCode: 'other',
        ),
        throwsA(isA<ShiftException>()),
      );
      expect(await db.select(db.cashMovements).get(), isEmpty);
      await (db.update(db.shifts)..where((s) => s.id.equals(shift.id))).write(
        const ShiftsCompanion(status: Value('closed')),
      );
      await expectLater(
        service.record(
          shiftId: shift.id,
          branchId: 'branch',
          deviceId: 'device',
          type: 'cash_out',
          amountMinor: 1,
          reasonCode: 'other',
        ),
        throwsA(isA<ShiftException>()),
      );
    },
  );

  test(
    'close stores exact, short, and over differences including no-sale close',
    () async {
      final repository = ShiftRepository(db);
      final summaryService = ShiftSummaryService(db, repository);
      for (final values in [(50000, 0), (49500, -500), (50200, 200)]) {
        final shift = await OpenShiftService(
          db,
        ).open(branchId: 'branch', deviceId: 'device', openingCashMinor: 50000);
        final closed = await CloseShiftService(
          db,
          summaryService,
        ).close(shift.id, values.$1, closedAt: at);
        expect(closed.shift.status, 'closed');
        expect(closed.cashDifferenceMinor, values.$2);
      }
    },
  );

  test(
    'closing persists snapshots, preserves pending sale events, and rejects repeats',
    () async {
      final shift = await OpenShiftService(
        db,
      ).open(branchId: 'branch', deviceId: 'device', openingCashMinor: 100000);
      await addCashSale(
        db,
        shift,
        id: 'sale',
        total: 19500,
        paid: 20000,
        change: 500,
      );
      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'sale-event',
              branchId: 'branch',
              deviceId: 'device',
              entityType: 'sale',
              entityId: 'sale',
              operation: 'append',
              entityVersion: 1,
              payloadJson: '{}',
              occurredAt: at,
              createdAt: at,
            ),
          );
      final close = CloseShiftService(
        db,
        ShiftSummaryService(db, ShiftRepository(db)),
      );
      final result = await close.close(shift.id, 119000);
      expect(result.shift.cashSalesMinor, 19500);
      expect(result.shift.expectedCashMinor, 119500);
      expect(result.shift.cashDifferenceMinor, -500);
      expect(result.shift.salesCount, 1);
      expect(result.shift.cashSalesCount, 1);
      expect(result.shift.grossSalesMinor, 19500);
      final closeEvent = (await db.select(db.syncOutbox).get()).last;
      final closePayload = jsonDecode(closeEvent.payloadJson) as Map;
      expect(closePayload['salesCount'], 1);
      expect(closePayload['cashSalesCount'], 1);
      expect(closePayload['grossSalesMinor'], 19500);

      await (db.update(db.sales)..where((sale) => sale.id.equals('sale')))
          .write(const SalesCompanion(status: Value('voided')));
      final immutable = await ShiftSummaryService(
        db,
        ShiftRepository(db),
      ).get(shift.id);
      expect(immutable.salesCount, 1);
      expect(immutable.cashSalesCount, 1);
      expect(immutable.grossSalesMinor, 19500);
      expect(immutable.cashSalesMinor, 19500);
      expect(
        (await db.select(db.syncOutbox).get()).any((e) => e.id == 'sale-event'),
        isTrue,
      );
      await expectLater(
        close.close(shift.id, 119500),
        throwsA(isA<ShiftException>()),
      );
    },
  );

  test('close outbox failure rolls back status and snapshots', () async {
    final shift = await OpenShiftService(
      db,
    ).open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0);
    final close = CloseShiftService(
      db,
      ShiftSummaryService(db, ShiftRepository(db)),
      failureHook: (_) => throw StateError('forced'),
    );
    await expectLater(close.close(shift.id, 0), throwsA(isA<ShiftException>()));
    final stored = await ShiftRepository(db).getShiftById(shift.id);
    expect(stored?.status, 'open');
    expect(stored?.closingCashMinor, null);
    expect(stored?.salesCount, 0);
    expect(stored?.cashSalesCount, 0);
    expect(stored?.grossSalesMinor, 0);
  });

  test('pending sync aggregates only related shift entities', () async {
    final shift = await OpenShiftService(
      db,
    ).open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0);
    await addCashSale(
      db,
      shift,
      id: 'sale-sync',
      total: 100,
      paid: 100,
      change: 0,
    );
    await (db.update(
      db.syncOutbox,
    )).write(const SyncOutboxCompanion(status: Value('synced')));
    final repository = ShiftRepository(db);

    await addOutbox(
      db,
      id: 'other-shift-event',
      entityType: 'shift',
      entityId: 'other-shift',
    );
    expect(await repository.isSyncPending(shift.id), isFalse);

    await addOutbox(
      db,
      id: 'sale-sync-event',
      entityType: 'sale',
      entityId: 'sale-sync',
    );
    expect(await repository.isSyncPending(shift.id), isTrue);
    await (db.update(db.syncOutbox)
          ..where((event) => event.id.equals('sale-sync-event')))
        .write(const SyncOutboxCompanion(status: Value('processing')));
    expect(await repository.isSyncPending(shift.id), isTrue);
    await (db.update(db.syncOutbox)
          ..where((event) => event.id.equals('sale-sync-event')))
        .write(const SyncOutboxCompanion(status: Value('synced')));

    final movement = await CashMovementService(db).record(
      shiftId: shift.id,
      branchId: 'branch',
      deviceId: 'device',
      type: 'cash_in',
      amountMinor: 1,
      reasonCode: 'other',
    );
    expect(await repository.isSyncPending(shift.id), isTrue);
    await (db.update(db.syncOutbox)..where(
          (event) =>
              event.entityType.equals('cash_movement') &
              event.entityId.equals(movement.id),
        ))
        .write(const SyncOutboxCompanion(status: Value('synced')));
    expect(await repository.isSyncPending(shift.id), isFalse);

    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: 'stock-sync',
            branchId: 'branch',
            deviceId: 'device',
            productId: 'product',
            type: 'sale',
            sourceUnitId: 'unit',
            sourceUnitCodeSnapshot: 'each',
            sourceUnitNameSnapshot: 'Each',
            sourceQuantityMinor: 1,
            sourceQuantityScale: 1,
            conversionNumeratorSnapshot: 1,
            conversionDenominatorSnapshot: 1,
            baseQuantityMinor: -1,
            baseQuantityScale: 1,
            referenceType: 'sale',
            referenceId: 'sale-sync',
            occurredAt: at,
            createdAt: at,
            version: 1,
          ),
        );
    await addOutbox(
      db,
      id: 'stock-sync-event',
      entityType: 'stock_movement',
      entityId: 'stock-sync',
    );
    expect(await repository.isSyncPending(shift.id), isTrue);
  });

  test('concurrent open and close requests have one winner', () async {
    final opens = await Future.wait([
      OpenShiftService(db)
          .open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0)
          .then((_) => true)
          .catchError((_) => false),
      OpenShiftService(db)
          .open(branchId: 'branch', deviceId: 'device', openingCashMinor: 0)
          .then((_) => true)
          .catchError((_) => false),
    ]);
    expect(opens.where((v) => v), hasLength(1));
    final shift = await ShiftRepository(db).getOpenShiftForDevice('device');
    final close = CloseShiftService(
      db,
      ShiftSummaryService(db, ShiftRepository(db)),
    );
    final closes = await Future.wait([
      close.close(shift!.id, 0).then((_) => true).catchError((_) => false),
      close.close(shift.id, 0).then((_) => true).catchError((_) => false),
    ]);
    expect(closes.where((v) => v), hasLength(1));
  });

  test('history orders shifts and detail relations remain offline', () async {
    final first = await OpenShiftService(db).open(
      branchId: 'branch',
      deviceId: 'device',
      openingCashMinor: 0,
      openedAt: at,
    );
    await CloseShiftService(
      db,
      ShiftSummaryService(db, ShiftRepository(db)),
    ).close(first.id, 0, closedAt: at);
    final second = await OpenShiftService(db).open(
      branchId: 'branch',
      deviceId: 'device',
      openingCashMinor: 0,
      openedAt: at.add(const Duration(hours: 1)),
    );
    await CashMovementService(db).record(
      shiftId: second.id,
      branchId: 'branch',
      deviceId: 'device',
      type: 'cash_in',
      amountMinor: 100,
      reasonCode: 'other',
    );
    final repo = ShiftRepository(db);
    expect((await repo.listRecentShifts()).first.id, second.id);
    expect(await repo.getShiftCashMovements(second.id), hasLength(1));
    expect(await repo.getShiftSales(first.id), isEmpty);
    expect(await repo.isSyncPending(second.id), isTrue);
  });
}
