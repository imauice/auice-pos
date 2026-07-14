import 'dart:convert';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const cashMovementTypes = {'cash_in', 'cash_out'};
const cashReasonCodes = {
  'petty_cash_in',
  'petty_cash_out',
  'cash_drop',
  'cash_float_adjustment',
  'expense',
  'other',
};

class ShiftException implements Exception {
  const ShiftException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ShiftFailurePoint { outbox }

typedef ShiftFailureHook = void Function(ShiftFailurePoint point);

class ShiftSummary {
  const ShiftSummary({
    required this.shift,
    required this.salesCount,
    required this.cashSalesCount,
    required this.cashSalesMinor,
    required this.grossSalesMinor,
    required this.cashInMinor,
    required this.cashOutMinor,
    required this.expectedCashMinor,
  });
  final Shift shift;
  final int salesCount,
      cashSalesCount,
      cashSalesMinor,
      grossSalesMinor,
      cashInMinor,
      cashOutMinor,
      expectedCashMinor;
  int? get closingCashMinor => shift.closingCashMinor;
  int? get cashDifferenceMinor => shift.cashDifferenceMinor;
}

class ShiftConfiguration {
  const ShiftConfiguration._({
    required this.status,
    this.branch,
    this.deviceId,
  });

  factory ShiftConfiguration.ready(Branche branch, String deviceId) =>
      ShiftConfiguration._(
        status: ShiftConfigurationStatus.ready,
        branch: branch,
        deviceId: deviceId,
      );

  const ShiftConfiguration.failure(ShiftConfigurationStatus status)
    : this._(status: status);

  final ShiftConfigurationStatus status;
  final Branche? branch;
  final String? deviceId;
  bool get isReady => status == ShiftConfigurationStatus.ready;
  String get message => switch (status) {
    ShiftConfigurationStatus.ready => 'Ready',
    ShiftConfigurationStatus.missingDeviceId => 'Device ID is not configured',
    ShiftConfigurationStatus.missingRegisteredBranchId =>
      'Registered branch is not configured',
    ShiftConfigurationStatus.inactiveDevice => 'Device is inactive',
    ShiftConfigurationStatus.invalidRegisteredBranch =>
      'Registered branch is missing, inactive, or deleted',
  };
}

enum ShiftConfigurationStatus {
  ready,
  missingDeviceId,
  missingRegisteredBranchId,
  inactiveDevice,
  invalidRegisteredBranch,
}

class ShiftRepository {
  ShiftRepository(this.db);
  final AppDatabase db;
  Future<Shift?> getOpenShiftForDevice(String deviceId) =>
      (db.select(db.shifts)..where(
            (r) =>
                r.deviceId.equals(deviceId) &
                r.status.equals('open') &
                r.deletedAt.isNull(),
          ))
          .getSingleOrNull();
  Future<Shift?> getShiftById(String id) => (db.select(
    db.shifts,
  )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
  Future<List<Shift>> listRecentShifts({int limit = 50}) =>
      (db.select(db.shifts)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm.desc(r.openedAt)])
            ..limit(limit))
          .get();
  Future<List<CashMovement>> getShiftCashMovements(String shiftId) =>
      (db.select(db.cashMovements)
            ..where((r) => r.shiftId.equals(shiftId))
            ..orderBy([(r) => OrderingTerm.asc(r.occurredAt)]))
          .get();
  Future<List<Sale>> getShiftSales(String shiftId) =>
      (db.select(db.sales)
            ..where(
              (r) =>
                  r.shiftId.equals(shiftId) &
                  r.status.equals('completed') &
                  r.deletedAt.isNull(),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.soldAt)]))
          .get();
  Future<ShiftSummary> getShiftSummary(String shiftId) =>
      ShiftSummaryService(db, this).get(shiftId);
  Future<bool> isSyncPending(String shiftId) async {
    final saleIds =
        await (db.selectOnly(db.sales)
              ..addColumns([db.sales.id])
              ..where(db.sales.shiftId.equals(shiftId)))
            .map((row) => row.read(db.sales.id)!)
            .get();
    final cashMovementIds =
        await (db.selectOnly(db.cashMovements)
              ..addColumns([db.cashMovements.id])
              ..where(db.cashMovements.shiftId.equals(shiftId)))
            .map((row) => row.read(db.cashMovements.id)!)
            .get();
    final stockMovementIds = saleIds.isEmpty
        ? <String>[]
        : await (db.selectOnly(db.stockMovements)
                ..addColumns([db.stockMovements.id])
                ..where(
                  db.stockMovements.referenceType.equals('sale') &
                      db.stockMovements.referenceId.isIn(saleIds),
                ))
              .map((row) => row.read(db.stockMovements.id)!)
              .get();

    var related =
        db.syncOutbox.entityType.equals('shift') &
        db.syncOutbox.entityId.equals(shiftId);
    if (saleIds.isNotEmpty) {
      related =
          related |
          (db.syncOutbox.entityType.equals('sale') &
              db.syncOutbox.entityId.isIn(saleIds));
    }
    if (cashMovementIds.isNotEmpty) {
      related =
          related |
          (db.syncOutbox.entityType.equals('cash_movement') &
              db.syncOutbox.entityId.isIn(cashMovementIds));
    }
    if (stockMovementIds.isNotEmpty) {
      related =
          related |
          (db.syncOutbox.entityType.equals('stock_movement') &
              db.syncOutbox.entityId.isIn(stockMovementIds));
    }
    return await (db.select(db.syncOutbox)
              ..where(
                (row) => row.status.isIn(['pending', 'processing']) & related,
              )
              ..limit(1))
            .getSingleOrNull() !=
        null;
  }
}

class ShiftSummaryService {
  ShiftSummaryService(this.db, this.repository);
  final AppDatabase db;
  final ShiftRepository repository;
  Future<ShiftSummary> get(String shiftId) async {
    final shift = await repository.getShiftById(shiftId);
    if (shift == null) throw const ShiftException('Shift not found');
    if (shift.status == 'closed') {
      return ShiftSummary(
        shift: shift,
        salesCount: shift.salesCount,
        cashSalesCount: shift.cashSalesCount,
        cashSalesMinor: shift.cashSalesMinor,
        grossSalesMinor: shift.grossSalesMinor,
        cashInMinor: shift.cashInMinor,
        cashOutMinor: shift.cashOutMinor,
        expectedCashMinor:
            shift.expectedCashMinor ??
            (shift.openingCashMinor +
                shift.cashSalesMinor +
                shift.cashInMinor -
                shift.cashOutMinor),
      );
    }
    final sales = await repository.getShiftSales(shiftId);
    final cashPayments = sales.isEmpty
        ? <Payment>[]
        : await (db.select(db.payments)..where(
                (p) =>
                    p.saleId.isIn(sales.map((sale) => sale.id)) &
                    p.method.equals('cash'),
              ))
              .get();
    final cashSaleIds = cashPayments.map((payment) => payment.saleId).toSet();
    final cashSalesCount = cashSaleIds.length;
    final cashSalesMinor =
        cashPayments.fold<int>(0, (sum, payment) => sum + payment.amountMinor) -
        sales
            .where((sale) => cashSaleIds.contains(sale.id))
            .fold<int>(0, (sum, sale) => sum + sale.changeMinor);
    final movements = await repository.getShiftCashMovements(shiftId);
    final calculatedIn = movements
        .where((m) => m.type == 'cash_in')
        .fold(0, (sum, m) => sum + m.amountMinor);
    final calculatedOut = movements
        .where((m) => m.type == 'cash_out')
        .fold(0, (sum, m) => sum + m.amountMinor);
    final cashSales = cashSalesMinor;
    final cashIn = calculatedIn;
    final cashOut = calculatedOut;
    return ShiftSummary(
      shift: shift,
      salesCount: sales.length,
      cashSalesCount: cashSalesCount,
      cashSalesMinor: cashSales,
      grossSalesMinor: sales.fold(0, (sum, sale) => sum + sale.totalMinor),
      cashInMinor: cashIn,
      cashOutMinor: cashOut,
      expectedCashMinor: shift.openingCashMinor + cashSales + cashIn - cashOut,
    );
  }
}

class OpenShiftService {
  OpenShiftService(this.db, {this.failureHook});
  final AppDatabase db;
  final ShiftFailureHook? failureHook;
  Future<Shift> open({
    required String branchId,
    required String deviceId,
    required int openingCashMinor,
    String currency = 'THB',
    DateTime? openedAt,
  }) async {
    if (openingCashMinor < 0) {
      throw const ShiftException('Invalid opening cash');
    }
    try {
      return await db.transaction(() async {
        final branch =
            await (db.select(db.branches)..where(
                  (b) =>
                      b.id.equals(branchId) &
                      b.active.equals(true) &
                      b.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (branch == null) throw const ShiftException('Inactive branch');
        final configured = await _metadata(db, 'device_id');
        final active = await _metadata(db, 'device_active');
        final registeredBranch = await _metadata(db, 'registered_branch_id');
        if (configured == null || configured != deviceId || active != 'true') {
          throw const ShiftException('Inactive device');
        }
        if (registeredBranch == null ||
            registeredBranch != branchId ||
            branch.currency != currency) {
          throw const ShiftException('Device branch mismatch');
        }
        if (await ShiftRepository(db).getOpenShiftForDevice(deviceId) != null) {
          throw const ShiftException('Shift already open');
        }
        final at = (openedAt ?? DateTime.now()).toUtc();
        final id = const Uuid().v7();
        await db
            .into(db.shifts)
            .insert(
              ShiftsCompanion.insert(
                id: id,
                branchId: branchId,
                deviceId: deviceId,
                status: 'open',
                openedAt: at,
                openingCashMinor: openingCashMinor,
                currency: currency,
                createdAt: at,
                updatedAt: at,
                version: 1,
              ),
            );
        final shift = await (db.select(
          db.shifts,
        )..where((s) => s.id.equals(id))).getSingle();
        failureHook?.call(ShiftFailurePoint.outbox);
        await _outbox(
          db,
          branchId,
          deviceId,
          'shift',
          id,
          'append',
          1,
          _shiftJson(shift),
          at,
        );
        return shift;
      });
    } on ShiftException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Open shift rolled back: $error\n$stack');
      throw const ShiftException('Database transaction failure');
    }
  }
}

class CashMovementService {
  CashMovementService(this.db, {this.failureHook});
  final AppDatabase db;
  final ShiftFailureHook? failureHook;
  Future<CashMovement> record({
    required String shiftId,
    required String branchId,
    required String deviceId,
    required String type,
    required int amountMinor,
    required String reasonCode,
    String currency = 'THB',
    String? note,
    DateTime? occurredAt,
  }) async {
    if (!cashMovementTypes.contains(type) ||
        !cashReasonCodes.contains(reasonCode) ||
        amountMinor <= 0) {
      throw const ShiftException('Invalid cash movement');
    }
    try {
      return await db.transaction(() async {
        final shift =
            await (db.select(
                  db.shifts,
                )..where((s) => s.id.equals(shiftId) & s.status.equals('open')))
                .getSingleOrNull();
        if (shift == null) throw const ShiftException('No open shift');
        if (shift.branchId != branchId ||
            shift.deviceId != deviceId ||
            shift.currency != currency) {
          throw const ShiftException('Device branch mismatch');
        }
        final at = (occurredAt ?? DateTime.now()).toUtc();
        final id = const Uuid().v7();
        await db
            .into(db.cashMovements)
            .insert(
              CashMovementsCompanion.insert(
                id: id,
                branchId: branchId,
                deviceId: deviceId,
                shiftId: shiftId,
                type: type,
                amountMinor: amountMinor,
                currency: currency,
                reasonCode: reasonCode,
                note: Value(note),
                occurredAt: at,
                createdAt: at,
                version: 1,
              ),
            );
        final movement = await (db.select(
          db.cashMovements,
        )..where((m) => m.id.equals(id))).getSingle();
        failureHook?.call(ShiftFailurePoint.outbox);
        await _outbox(
          db,
          branchId,
          deviceId,
          'cash_movement',
          id,
          'append',
          1,
          _cashJson(movement),
          at,
        );
        return movement;
      });
    } on ShiftException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Cash movement rolled back: $error\n$stack');
      throw const ShiftException('Database transaction failure');
    }
  }
}

class CloseShiftService {
  CloseShiftService(this.db, this.summaryService, {this.failureHook});
  final AppDatabase db;
  final ShiftSummaryService summaryService;
  final ShiftFailureHook? failureHook;
  Future<ShiftSummary> close(
    String shiftId,
    int closingCashMinor, {
    DateTime? closedAt,
  }) async {
    if (closingCashMinor < 0) {
      throw const ShiftException('Invalid closing cash');
    }
    try {
      return await db.transaction(() async {
        final shift = await (db.select(
          db.shifts,
        )..where((s) => s.id.equals(shiftId))).getSingleOrNull();
        if (shift == null || shift.status == 'closed') {
          throw const ShiftException('Shift already closed');
        }
        if (shift.status == 'cancelled') {
          throw const ShiftException('Shift cancelled');
        }
        final summary = await summaryService.get(shiftId);
        final at = (closedAt ?? DateTime.now()).toUtc();
        final updated =
            await (db.update(
                  db.shifts,
                )..where((s) => s.id.equals(shiftId) & s.status.equals('open')))
                .write(
                  ShiftsCompanion(
                    status: const Value('closed'),
                    closedAt: Value(at),
                    cashSalesMinor: Value(summary.cashSalesMinor),
                    cashInMinor: Value(summary.cashInMinor),
                    cashOutMinor: Value(summary.cashOutMinor),
                    salesCount: Value(summary.salesCount),
                    cashSalesCount: Value(summary.cashSalesCount),
                    grossSalesMinor: Value(summary.grossSalesMinor),
                    expectedCashMinor: Value(summary.expectedCashMinor),
                    closingCashMinor: Value(closingCashMinor),
                    cashDifferenceMinor: Value(
                      closingCashMinor - summary.expectedCashMinor,
                    ),
                    updatedAt: Value(at),
                    version: Value(shift.version + 1),
                  ),
                );
        if (updated != 1) throw const ShiftException('Shift already closed');
        final closed = await (db.select(
          db.shifts,
        )..where((s) => s.id.equals(shiftId))).getSingle();
        failureHook?.call(ShiftFailurePoint.outbox);
        await _outbox(
          db,
          closed.branchId,
          closed.deviceId,
          'shift',
          closed.id,
          'update',
          closed.version,
          _shiftJson(closed),
          at,
        );
        return summaryService.get(shiftId);
      });
    } on ShiftException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Close shift rolled back: $error\n$stack');
      throw const ShiftException('Database transaction failure');
    }
  }
}

// Test-only POS-004 fixture helper. Production UI never calls this.
class ShiftService {
  ShiftService(this.db);
  final AppDatabase db;
  Future<Shift> ensureDevelopmentShift(
    String branchId,
    String deviceId,
  ) => db.transaction(() async {
    final existing = await ShiftRepository(db).getOpenShiftForDevice(deviceId);
    if (existing != null) return existing;
    final at = DateTime.now().toUtc();
    final id = const Uuid().v7();
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            id: id,
            branchId: branchId,
            deviceId: deviceId,
            status: 'open',
            openedAt: at,
            openingCashMinor: 0,
            currency: 'THB',
            createdAt: at,
            updatedAt: at,
            version: 1,
          ),
        );
    return (db.select(db.shifts)..where((s) => s.id.equals(id))).getSingle();
  });
}

Future<String?> _metadata(AppDatabase db, String key) async =>
    (await (db.select(
      db.appMetadata,
    )..where((m) => m.key.equals(key))).getSingleOrNull())?.value;
Future<void> _outbox(
  AppDatabase db,
  String branchId,
  String deviceId,
  String type,
  String entityId,
  String operation,
  int version,
  Map<String, dynamic> payload,
  DateTime at,
) => db
    .into(db.syncOutbox)
    .insert(
      SyncOutboxCompanion.insert(
        id: const Uuid().v7(),
        branchId: branchId,
        deviceId: deviceId,
        entityType: type,
        entityId: entityId,
        operation: operation,
        entityVersion: version,
        payloadJson: jsonEncode(payload),
        occurredAt: at,
        createdAt: at,
      ),
    );
Map<String, dynamic> _shiftJson(Shift s) => {
  'id': s.id,
  'branchId': s.branchId,
  'deviceId': s.deviceId,
  'status': s.status,
  'openedAt': s.openedAt.toIso8601String(),
  'closedAt': s.closedAt?.toIso8601String(),
  'openingCashMinor': s.openingCashMinor,
  'cashSalesMinor': s.cashSalesMinor,
  'cashInMinor': s.cashInMinor,
  'cashOutMinor': s.cashOutMinor,
  'salesCount': s.salesCount,
  'cashSalesCount': s.cashSalesCount,
  'grossSalesMinor': s.grossSalesMinor,
  'expectedCashMinor': s.expectedCashMinor,
  'closingCashMinor': s.closingCashMinor,
  'cashDifferenceMinor': s.cashDifferenceMinor,
  'currency': s.currency,
  'createdAt': s.createdAt.toIso8601String(),
  'updatedAt': s.updatedAt.toIso8601String(),
  'version': s.version,
  'deletedAt': s.deletedAt?.toIso8601String(),
};
Map<String, dynamic> _cashJson(CashMovement m) => {
  'id': m.id,
  'branchId': m.branchId,
  'deviceId': m.deviceId,
  'shiftId': m.shiftId,
  'type': m.type,
  'amountMinor': m.amountMinor,
  'currency': m.currency,
  'reasonCode': m.reasonCode,
  'note': m.note,
  'occurredAt': m.occurredAt.toIso8601String(),
  'createdAt': m.createdAt.toIso8601String(),
  'version': m.version,
};

final shiftRepositoryProvider = Provider(
  (ref) => ShiftRepository(ref.watch(databaseProvider)),
);
final shiftSummaryServiceProvider = Provider(
  (ref) => ShiftSummaryService(
    ref.watch(databaseProvider),
    ref.watch(shiftRepositoryProvider),
  ),
);
final openShiftServiceProvider = Provider(
  (ref) => OpenShiftService(ref.watch(databaseProvider)),
);
final cashMovementServiceProvider = Provider(
  (ref) => CashMovementService(ref.watch(databaseProvider)),
);
final closeShiftServiceProvider = Provider(
  (ref) => CloseShiftService(
    ref.watch(databaseProvider),
    ref.watch(shiftSummaryServiceProvider),
  ),
);
final openShiftProvider = FutureProvider<Shift?>((ref) async {
  final db = ref.watch(databaseProvider);
  final device = await _metadata(db, 'device_id');
  return device == null
      ? null
      : ref.watch(shiftRepositoryProvider).getOpenShiftForDevice(device);
});
final shiftSummaryProvider = FutureProvider.family<ShiftSummary, String>(
  (ref, id) => ref.watch(shiftSummaryServiceProvider).get(id),
);
final shiftSyncPendingProvider = FutureProvider.family<bool, String>(
  (ref, id) => ref.watch(shiftRepositoryProvider).isSyncPending(id),
);
final recentShiftsProvider = FutureProvider<List<Shift>>(
  (ref) => ref.watch(shiftRepositoryProvider).listRecentShifts(),
);
Future<ShiftConfiguration> loadShiftConfiguration(AppDatabase db) async {
  final device = await _metadata(db, 'device_id');
  if (device == null || device.isEmpty) {
    return const ShiftConfiguration.failure(
      ShiftConfigurationStatus.missingDeviceId,
    );
  }
  final branchId = await _metadata(db, 'registered_branch_id');
  if (branchId == null || branchId.isEmpty) {
    return const ShiftConfiguration.failure(
      ShiftConfigurationStatus.missingRegisteredBranchId,
    );
  }
  if (await _metadata(db, 'device_active') != 'true') {
    return const ShiftConfiguration.failure(
      ShiftConfigurationStatus.inactiveDevice,
    );
  }
  final branch =
      await (db.select(db.branches)..where(
            (row) =>
                row.id.equals(branchId) &
                row.active.equals(true) &
                row.deletedAt.isNull(),
          ))
          .getSingleOrNull();
  if (branch == null) {
    return const ShiftConfiguration.failure(
      ShiftConfigurationStatus.invalidRegisteredBranch,
    );
  }
  return ShiftConfiguration.ready(branch, device);
}

final shiftConfigurationProvider = FutureProvider<ShiftConfiguration>((ref) {
  final db = ref.watch(databaseProvider);
  return loadShiftConfiguration(db);
});
