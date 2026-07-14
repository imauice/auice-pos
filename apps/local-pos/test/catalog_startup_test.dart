import 'package:auice_pos/core/catalog/catalog_gateway.dart';
import 'package:auice_pos/core/catalog/catalog_import_service.dart';
import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/startup/catalog_startup_coordinator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements CatalogGateway {
  FakeGateway(this.online, {this.pages = const [], this.catalogVersion = 1});
  final bool online;
  final List<CatalogPage> pages;
  final int catalogVersion;
  int pulls = 0;
  final cursors = <String?>[];
  @override
  Future<bool> isOnline() async => online;
  @override
  Future<RegistrationResult> register(String id) async =>
      RegistrationResult(branchId: 'branch', catalogVersion: catalogVersion);
  @override
  Future<Map<String, dynamic>> fetchBranch(String id) async => {
    'id': id,
    'code': 'BKK01',
    'name': 'Bangkok',
    'timezone': 'Asia/Bangkok',
    'currency': 'THB',
    'active': true,
    'version': 1,
    'updatedAt': '2026-01-01T00:00:00.000Z',
  };
  @override
  Future<CatalogPage> pull({
    required String branchId,
    required int fromVersion,
    String? cursor,
  }) async {
    cursors.add(cursor);
    return pages[pulls++];
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('first run offline requires connection', () async {
    final coordinator = CatalogStartupCoordinator(
      db: db,
      gateway: FakeGateway(false),
      importer: CatalogImportService(db),
    );
    await coordinator.start();
    expect(coordinator.state, CatalogStartupState.firstRunNeedsConnection);
  });
  test('existing local catalog is ready offline', () async {
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: 'p',
            branchId: 'b',
            name: 'Local',
            trackStock: false,
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: DateTime.utc(2026),
          ),
        );
    final states = <CatalogStartupState>[];
    final coordinator = CatalogStartupCoordinator(
      db: db,
      gateway: FakeGateway(false),
      importer: CatalogImportService(db),
      onState: states.add,
    );
    await coordinator.start();
    expect(states, contains(CatalogStartupState.readyOffline));
    expect(coordinator.state, CatalogStartupState.readyOffline);
  });
  test('online startup registers, imports, and becomes ready', () async {
    final page = CatalogPage(
      fromVersion: 0,
      targetVersion: 1,
      hasMore: false,
      categories: const [],
      products: [
        {
          'id': 'p',
          'branchId': 'branch',
          'categoryId': null,
          'sku': 'S',
          'name': 'Snack',
          'description': null,
          'baseUnitId': null,
          'trackStock': false,
          'active': true,
          'version': 1,
          'catalogVersion': 1,
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'deletedAt': null,
        },
      ],
      productUnits: const [],
      productPrices: const [],
    );
    final gateway = FakeGateway(true, pages: [page]);
    final coordinator = CatalogStartupCoordinator(
      db: db,
      gateway: gateway,
      importer: CatalogImportService(db),
    );
    await coordinator.start();
    expect(coordinator.state, CatalogStartupState.readyOnline);
    expect(await db.select(db.products).get(), hasLength(1));
    expect(await CatalogImportService(db).lastVersion(), 1);
  });
  test(
    'recreated coordinator resumes persisted cursor and only then finalizes',
    () async {
      final firstImporter = CatalogImportService(db);
      await firstImporter.importPage(
        CatalogPage(
          fromVersion: 0,
          targetVersion: 3,
          hasMore: true,
          nextCursor: 'persisted-cursor',
          categories: const [],
          products: [
            {
              'id': 'p',
              'branchId': 'branch',
              'categoryId': null,
              'sku': 'S',
              'name': 'First page',
              'description': null,
              'baseUnitId': null,
              'trackStock': false,
              'active': true,
              'version': 1,
              'catalogVersion': 1,
              'updatedAt': '2026-01-01T00:00:00.000Z',
              'deletedAt': null,
            },
          ],
          productUnits: const [],
          productPrices: const [],
        ),
      );
      expect(await firstImporter.lastVersion(), 0);

      final finalPage = CatalogPage(
        fromVersion: 0,
        targetVersion: 3,
        hasMore: false,
        categories: const [],
        products: const [],
        productUnits: const [],
        productPrices: const [],
      );
      final gateway = FakeGateway(true, pages: [finalPage], catalogVersion: 3);
      final recreatedImporter = CatalogImportService(db);
      final recreatedCoordinator = CatalogStartupCoordinator(
        db: db,
        gateway: gateway,
        importer: recreatedImporter,
      );
      await recreatedCoordinator.start();

      expect(gateway.cursors, ['persisted-cursor']);
      expect(await recreatedImporter.pendingCursor(), isNull);
      expect(await recreatedImporter.lastVersion(), 3);
      expect(recreatedCoordinator.state, CatalogStartupState.readyOnline);
    },
  );
}
