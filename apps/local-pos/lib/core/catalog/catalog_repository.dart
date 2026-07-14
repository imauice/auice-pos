import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeCatalogResult {
  const BarcodeCatalogResult(this.product, this.unit, this.price);
  final Product product;
  final ProductUnit unit;
  final ProductPrice? price;
}

typedef CatalogSaleOption = BarcodeCatalogResult;

class CatalogRepository {
  CatalogRepository(this.db);
  final AppDatabase db;
  Future<BarcodeCatalogResult?> findByBarcode(
    String branchId,
    String barcode, {
    DateTime? at,
  }) async {
    final unit =
        await (db.select(db.productUnits)..where(
              (r) =>
                  r.branchId.equals(branchId) &
                  r.barcode.equals(barcode) &
                  r.active.equals(true) &
                  r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (unit == null) return null;
    final product = await _activeProduct(unit.productId);
    if (product == null) return null;
    return BarcodeCatalogResult(
      product,
      unit,
      await findCurrentProductPrice(unit.id, at: at),
    );
  }

  Future<Product?> findBySku(String branchId, String sku) =>
      (db.select(db.products)..where(
            (r) =>
                r.branchId.equals(branchId) &
                r.sku.equals(sku) &
                r.active.equals(true) &
                r.deletedAt.isNull(),
          ))
          .getSingleOrNull();
  Future<List<Product>> findByName(String branchId, String name) =>
      (db.select(db.products)..where(
            (r) =>
                r.branchId.equals(branchId) &
                r.name.lower().contains(name.toLowerCase()) &
                r.active.equals(true) &
                r.deletedAt.isNull(),
          ))
          .get();
  Future<List<CatalogSaleOption>> searchSaleOptions(
    String branchId,
    String query,
  ) async {
    final byBarcode = await findByBarcode(branchId, query);
    if (byBarcode != null && byBarcode.price != null) return [byBarcode];
    final sku = await findBySku(branchId, query);
    final products = sku == null ? await findByName(branchId, query) : [sku];
    final results = <CatalogSaleOption>[];
    for (final product in products) {
      for (final unit in await findProductUnits(product.id)) {
        final price = await findCurrentProductPrice(unit.id);
        if (unit.allowSale && price != null) {
          results.add(CatalogSaleOption(product, unit, price));
        }
      }
    }
    return results;
  }

  Future<List<ProductUnit>> findProductUnits(String productId) =>
      (db.select(db.productUnits)..where(
            (r) =>
                r.productId.equals(productId) &
                r.active.equals(true) &
                r.deletedAt.isNull(),
          ))
          .get();
  Future<ProductPrice?> findCurrentProductPrice(
    String productUnitId, {
    DateTime? at,
  }) {
    final time = at ?? DateTime.now().toUtc();
    return (db.select(db.productPrices)
          ..where(
            (r) =>
                r.productUnitId.equals(productUnitId) &
                r.active.equals(true) &
                r.deletedAt.isNull() &
                r.effectiveFrom.isSmallerOrEqualValue(time) &
                (r.effectiveTo.isNull() |
                    r.effectiveTo.isBiggerThanValue(time)),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.effectiveFrom)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Product?> _activeProduct(String id) =>
      (db.select(db.products)..where(
            (r) =>
                r.id.equals(id) & r.active.equals(true) & r.deletedAt.isNull(),
          ))
          .getSingleOrNull();
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(databaseProvider)),
);
