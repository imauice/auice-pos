import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogImportService {
  CatalogImportService(this.db);
  final AppDatabase db;
  Future<void> importBranch(Map<String, dynamic> j, int catalogVersion) => db
      .into(db.branches)
      .insertOnConflictUpdate(
        BranchesCompanion.insert(
          id: j['id'] as String,
          code: j['code'] as String,
          name: j['name'] as String,
          timezone: j['timezone'] as String,
          currency: j['currency'] as String,
          active: j['active'] as bool,
          version: j['version'] as int,
          catalogVersion: catalogVersion,
          updatedAt: _date(j['updatedAt']!),
          deletedAt: const Value(null),
        ),
      );
  DateTime _date(Object value) => DateTime.parse(value as String).toUtc();
  DateTime? _optionalDate(Object? value) => value == null ? null : _date(value);
  Future<void> importPage(CatalogPage page) => db.transaction(() async {
    for (final j in page.categories) {
      await db
          .into(db.categories)
          .insertOnConflictUpdate(
            CategoriesCompanion.insert(
              id: j['id'] as String,
              branchId: j['branchId'] as String,
              name: j['name'] as String,
              description: Value(j['description'] as String?),
              sortOrder: j['sortOrder'] as int,
              active: j['active'] as bool,
              version: j['version'] as int,
              catalogVersion: j['catalogVersion'] as int,
              updatedAt: _date(j['updatedAt']!),
              deletedAt: Value(_optionalDate(j['deletedAt'])),
            ),
          );
    }
    for (final j in page.products) {
      await db
          .into(db.products)
          .insertOnConflictUpdate(
            ProductsCompanion.insert(
              id: j['id'] as String,
              branchId: j['branchId'] as String,
              categoryId: Value(j['categoryId'] as String?),
              sku: Value(j['sku'] as String?),
              name: j['name'] as String,
              description: Value(j['description'] as String?),
              baseUnitId: Value(j['baseUnitId'] as String?),
              trackStock: j['trackStock'] as bool,
              active: j['active'] as bool,
              version: j['version'] as int,
              catalogVersion: j['catalogVersion'] as int,
              updatedAt: _date(j['updatedAt']!),
              deletedAt: Value(_optionalDate(j['deletedAt'])),
            ),
          );
    }
    for (final j in page.productUnits) {
      await db
          .into(db.productUnits)
          .insertOnConflictUpdate(
            ProductUnitsCompanion.insert(
              id: j['id'] as String,
              branchId: j['branchId'] as String,
              productId: j['productId'] as String,
              code: j['code'] as String,
              name: j['name'] as String,
              unitCategory: j['unitCategory'] as String,
              isBaseUnit: j['isBaseUnit'] as bool,
              conversionNumerator: j['conversionNumerator'] as int,
              conversionDenominator: j['conversionDenominator'] as int,
              barcode: Value(j['barcode'] as String?),
              allowSale: j['allowSale'] as bool,
              allowPurchase: j['allowPurchase'] as bool,
              active: j['active'] as bool,
              version: j['version'] as int,
              catalogVersion: j['catalogVersion'] as int,
              updatedAt: _date(j['updatedAt']!),
              deletedAt: Value(_optionalDate(j['deletedAt'])),
            ),
          );
    }
    for (final j in page.productPrices) {
      await db
          .into(db.productPrices)
          .insertOnConflictUpdate(
            ProductPricesCompanion.insert(
              id: j['id'] as String,
              branchId: j['branchId'] as String,
              productId: j['productId'] as String,
              productUnitId: j['productUnitId'] as String,
              priceMinor: j['priceMinor'] as int,
              currency: j['currency'] as String,
              effectiveFrom: _date(j['effectiveFrom']!),
              effectiveTo: Value(_optionalDate(j['effectiveTo'])),
              active: j['active'] as bool,
              version: j['version'] as int,
              catalogVersion: j['catalogVersion'] as int,
              updatedAt: _date(j['updatedAt']!),
              deletedAt: Value(_optionalDate(j['deletedAt'])),
            ),
          );
    }
    final now = DateTime.now().toUtc();
    if (page.hasMore) {
      if (page.nextCursor == null) {
        throw StateError('A non-final page requires nextCursor');
      }
      await _metadata('pending_catalog_cursor', page.nextCursor!, now);
    } else {
      await _metadata(
        'last_catalog_version',
        page.targetVersion.toString(),
        now,
      );
      await _metadata('pending_catalog_cursor', '', now);
    }
  });
  Future<void> _metadata(String key, String value, DateTime now) => db
      .into(db.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(key: key, value: value, updatedAt: now),
      );
  Future<int> lastVersion() async {
    final row = await (db.select(
      db.appMetadata,
    )..where((r) => r.key.equals('last_catalog_version'))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  Future<String?> pendingCursor() async {
    final row = await (db.select(
      db.appMetadata,
    )..where((r) => r.key.equals('pending_catalog_cursor'))).getSingleOrNull();
    return row == null || row.value.isEmpty ? null : row.value;
  }
}

final catalogImportServiceProvider = Provider<CatalogImportService>(
  (ref) => CatalogImportService(ref.watch(databaseProvider)),
);
