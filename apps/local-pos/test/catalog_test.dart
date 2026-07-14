import 'package:auice_pos/core/catalog/catalog_import_service.dart';
import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:auice_pos/core/catalog/catalog_repository.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const branch = '018f6f62-4b1d-7000-8000-000000000001';
const product = '018f6f62-4b1d-7000-8000-000000000002';
const bottle = '018f6f62-4b1d-7000-8000-000000000003';
const caseUnit = '018f6f62-4b1d-7000-8000-000000000004';
Map<String, dynamic> productJson({int catalog = 1, String? deletedAt}) => {
  'id': product,
  'branchId': branch,
  'categoryId': null,
  'sku': 'BEER',
  'name': 'Beer A',
  'description': null,
  'baseUnitId': bottle,
  'trackStock': true,
  'baseQuantityScale': 1,
  'lowStockThresholdMinor': 5,
  'lowStockThresholdScale': 1,
  'active': true,
  'version': catalog,
  'catalogVersion': catalog,
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'deletedAt': deletedAt,
};
Map<String, dynamic> unit(
  String id,
  String code,
  String barcode,
  int conversion,
) => {
  'id': id,
  'branchId': branch,
  'productId': product,
  'code': code,
  'name': code,
  'unitCategory': 'count',
  'isBaseUnit': conversion == 1,
  'conversionNumerator': conversion,
  'conversionDenominator': 1,
  'barcode': barcode,
  'allowSale': true,
  'allowPurchase': true,
  'active': true,
  'version': 1,
  'catalogVersion': 1,
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'deletedAt': null,
};
Map<String, dynamic> price(
  String id,
  String unit,
  int amount,
  DateTime from, {
  DateTime? to,
}) => {
  'id': id,
  'branchId': branch,
  'productId': product,
  'productUnitId': unit,
  'priceMinor': amount,
  'currency': 'THB',
  'effectiveFrom': from.toUtc().toIso8601String(),
  'effectiveTo': to?.toUtc().toIso8601String(),
  'active': true,
  'version': 1,
  'catalogVersion': 1,
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'deletedAt': null,
};
CatalogPage page({
  int target = 1,
  bool more = false,
  String? cursor,
  List<Map<String, dynamic>>? products,
  List<Map<String, dynamic>>? units,
  List<Map<String, dynamic>>? prices,
}) => CatalogPage(
  fromVersion: 0,
  targetVersion: target,
  hasMore: more,
  nextCursor: cursor,
  categories: const [],
  products: products ?? [],
  productUnits: units ?? [],
  productPrices: prices ?? [],
);
void main() {
  late AppDatabase db;
  late CatalogImportService importer;
  late CatalogRepository repository;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = CatalogImportService(db);
    repository = CatalogRepository(db);
  });
  tearDown(() => db.close());
  test('full and incremental imports update version and soft-delete', () async {
    await importer.importPage(page(products: [productJson()]));
    expect(await importer.lastVersion(), 1);
    expect(
      (await db.select(db.products).getSingle()).lowStockThresholdMinor,
      5,
    );
    await importer.importPage(
      page(
        target: 2,
        products: [
          productJson(catalog: 2, deletedAt: '2026-02-01T00:00:00.000Z'),
        ],
      ),
    );
    expect((await db.select(db.products).getSingle()).deletedAt, isNotNull);
    expect(await importer.lastVersion(), 2);
  });
  test('catalog rejects low-stock threshold scale mismatch', () async {
    final invalid = productJson()..['lowStockThresholdScale'] = 1000;
    await expectLater(
      importer.importPage(page(products: [invalid])),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.products).get(), isEmpty);
  });
  test('page rollback preserves no partial records', () async {
    final bad = productJson()..remove('name');
    expect(
      () => importer.importPage(
        page(products: [bad], units: [unit(bottle, 'bottle', '111', 1)]),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.productUnits).get(), isEmpty);
    expect(await importer.lastVersion(), 0);
  });
  test(
    'multipage import persists cursor and only finalizes target on last page',
    () async {
      await importer.importPage(
        page(target: 3, more: true, cursor: 'next', products: [productJson()]),
      );
      expect(await importer.pendingCursor(), 'next');
      expect(await importer.lastVersion(), 0);
      await importer.importPage(
        page(target: 3, units: [unit(bottle, 'bottle', '111', 1)]),
      );
      expect(await importer.pendingCursor(), isNull);
      expect(await importer.lastVersion(), 3);
    },
  );
  test('barcode selects bottle/case unit and its current price', () async {
    final now = DateTime.utc(2026, 6);
    await importer.importPage(
      page(
        products: [productJson()],
        units: [
          unit(bottle, 'bottle', '111', 1),
          unit(caseUnit, 'case', '222', 12),
        ],
        prices: [
          price('p1', bottle, 6500, DateTime.utc(2026)),
          price('p2', caseUnit, 72000, DateTime.utc(2026)),
        ],
      ),
    );
    expect(
      (await repository.findByBarcode(
        branch,
        '111',
        at: now,
      ))?.price?.priceMinor,
      6500,
    );
    final caseResult = await repository.findByBarcode(branch, '222', at: now);
    expect(caseResult?.unit.id, caseUnit);
    expect(caseResult?.price?.priceMinor, 72000);
    expect((await repository.findBySku(branch, 'BEER'))?.id, product);
    expect(await repository.findByName(branch, 'beer'), hasLength(1));
    final snackProduct = productJson()
      ..['id'] = 'snack'
      ..['sku'] = 'SNACK'
      ..['name'] = 'Snack A'
      ..['baseUnitId'] = 'small';
    final snackUnit = unit(bottle, 'small', '333', 1)
      ..['id'] = 'small'
      ..['productId'] = 'snack';
    final snackPrice = price('sp', 'small', 2500, DateTime.utc(2026))
      ..['productId'] = 'snack';
    await importer.importPage(
      page(products: [snackProduct], units: [snackUnit], prices: [snackPrice]),
    );
    final snack = await repository.findByBarcode(branch, '333', at: now);
    expect(snack?.product.name, 'Snack A');
    expect(snack?.unit.id, 'small');
    expect(snack?.price?.priceMinor, 2500);
  });
  test('current price respects effective time range', () async {
    final now = DateTime.utc(2026, 6);
    await importer.importPage(
      page(
        products: [productJson()],
        units: [unit(bottle, 'bottle', '111', 1)],
        prices: [
          price(
            'old',
            bottle,
            6000,
            DateTime.utc(2025),
            to: DateTime.utc(2026, 1),
          ),
          price('current', bottle, 6500, DateTime.utc(2026, 1)),
        ],
      ),
    );
    expect(
      (await repository.findCurrentProductPrice(bottle, at: now))?.id,
      'current',
    );
  });
}
