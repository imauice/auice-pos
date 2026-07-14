import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class ShiftService {
  ShiftService(this.db);
  final AppDatabase db;
  Future<Shift> ensureDevelopmentShift(String branchId, String deviceId) =>
      db.transaction(() async {
        final existing =
            await (db.select(db.shifts)..where(
                  (row) =>
                      row.deviceId.equals(deviceId) & row.status.equals('open'),
                ))
                .getSingleOrNull();
        if (existing != null) return existing;
        final now = DateTime.now().toUtc();
        final id = const Uuid().v7();
        await db
            .into(db.shifts)
            .insert(
              ShiftsCompanion.insert(
                id: id,
                branchId: branchId,
                deviceId: deviceId,
                status: 'open',
                openedAt: now,
                openingCashMinor: 0,
                currency: 'THB',
                createdAt: now,
                updatedAt: now,
                version: 1,
              ),
            );
        return (db.select(
          db.shifts,
        )..where((row) => row.id.equals(id))).getSingle();
      });
}

final shiftServiceProvider = Provider<ShiftService>(
  (ref) => ShiftService(ref.watch(databaseProvider)),
);
final openShiftProvider = FutureProvider<Shift?>((ref) async {
  final db = ref.watch(databaseProvider);
  final branch = await db.select(db.branches).getSingleOrNull();
  final device = await (db.select(
    db.appMetadata,
  )..where((row) => row.key.equals('device_id'))).getSingleOrNull();
  if (branch == null || device == null) return null;
  return ref
      .watch(shiftServiceProvider)
      .ensureDevelopmentShift(branch.id, device.value);
});
