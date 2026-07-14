import 'package:auice_pos/core/catalog/catalog_gateway.dart';
import 'package:auice_pos/core/catalog/catalog_import_service.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CatalogStartupState {
  loadingLocal,
  readyOffline,
  registering,
  syncingCatalog,
  readyOnline,
  syncFailedUsingLocal,
  firstRunNeedsConnection,
}

class CatalogStartupCoordinator {
  CatalogStartupCoordinator({
    required this.db,
    required this.gateway,
    required this.importer,
    this.onState,
  });
  final AppDatabase db;
  final CatalogGateway gateway;
  final CatalogImportService importer;
  void Function(CatalogStartupState)? onState;
  CatalogStartupState state = CatalogStartupState.loadingLocal;
  void _state(CatalogStartupState next) {
    state = next;
    onState?.call(next);
  }

  Future<void> start() async {
    await db.initialize();
    _state(CatalogStartupState.loadingLocal);
    final hasLocal = (await db.select(db.products).get()).isNotEmpty;
    if (hasLocal) _state(CatalogStartupState.readyOffline);
    if (!await gateway.isOnline()) {
      _state(
        hasLocal
            ? CatalogStartupState.readyOffline
            : CatalogStartupState.firstRunNeedsConnection,
      );
      return;
    }
    try {
      _state(CatalogStartupState.registering);
      final registration = await gateway.register(await _deviceId());
      final registeredAt = DateTime.now().toUtc();
      await db
          .into(db.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'registered_branch_id',
              value: registration.branchId,
              updatedAt: registeredAt,
            ),
          );
      await db
          .into(db.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'device_active',
              value: 'true',
              updatedAt: registeredAt,
            ),
          );
      await importer.importBranch(
        await gateway.fetchBranch(registration.branchId),
        registration.catalogVersion,
      );
      var from = await importer.lastVersion();
      var cursor = await importer.pendingCursor();
      if (from < registration.catalogVersion || cursor != null) {
        _state(CatalogStartupState.syncingCatalog);
        do {
          final page = await gateway.pull(
            branchId: registration.branchId,
            fromVersion: from,
            cursor: cursor,
          );
          await importer.importPage(page);
          cursor = page.hasMore ? page.nextCursor : null;
        } while (cursor != null);
      }
      _state(CatalogStartupState.readyOnline);
    } catch (_) {
      _state(
        hasLocal
            ? CatalogStartupState.syncFailedUsingLocal
            : CatalogStartupState.firstRunNeedsConnection,
      );
    }
  }

  Future<String> _deviceId() async {
    final existing = await (db.select(
      db.appMetadata,
    )..where((r) => r.key.equals('device_id'))).getSingleOrNull();
    if (existing != null) return existing.value;
    final id = const Uuid().v7();
    await db
        .into(db.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: 'device_id',
            value: id,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    return id;
  }
}

final catalogStartupCoordinatorProvider = Provider<CatalogStartupCoordinator>(
  (ref) => CatalogStartupCoordinator(
    db: ref.watch(databaseProvider),
    gateway: ref.watch(catalogGatewayProvider),
    importer: ref.watch(catalogImportServiceProvider),
  ),
);

class CatalogStartupStateController extends StateNotifier<CatalogStartupState> {
  CatalogStartupStateController(this.coordinator)
    : super(CatalogStartupState.loadingLocal) {
    coordinator.onState = (next) => state = next;
  }
  final CatalogStartupCoordinator coordinator;

  Future<void> start() => coordinator.start();
}

final catalogStartupStateProvider =
    StateNotifierProvider<CatalogStartupStateController, CatalogStartupState>(
      (ref) => CatalogStartupStateController(
        ref.watch(catalogStartupCoordinatorProvider),
      ),
    );
