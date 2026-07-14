import 'package:auice_pos/core/database/app_database.dart';

class CatalogIntegrityException implements Exception {
  const CatalogIntegrityException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CatalogIntegrityValidator {
  static void validateOption({
    required Product product,
    required ProductUnit unit,
    required ProductPrice price,
    String supportedCurrency = 'THB',
  }) {
    if (unit.productId != product.id) {
      throw const CatalogIntegrityException('Unit belongs to another product');
    }
    if (price.productId != product.id) {
      throw const CatalogIntegrityException('Price belongs to another product');
    }
    if (price.productUnitId != unit.id) {
      throw const CatalogIntegrityException('Price belongs to another unit');
    }
    if (unit.branchId != product.branchId ||
        price.branchId != product.branchId) {
      throw const CatalogIntegrityException('Catalog option crosses branches');
    }
    if (price.currency != supportedCurrency) {
      throw const CatalogIntegrityException('Unsupported price currency');
    }
    if (!product.active || product.deletedAt != null) {
      throw const CatalogIntegrityException('Product unavailable');
    }
    if (!unit.active || !unit.allowSale || unit.deletedAt != null) {
      throw const CatalogIntegrityException('Product unit unavailable');
    }
    if (!price.active || price.deletedAt != null) {
      throw const CatalogIntegrityException('Price unavailable');
    }
    if (product.trackStock && product.baseQuantityScale <= 0) {
      throw const CatalogIntegrityException('Invalid canonical stock scale');
    }
  }

  static void validateCheckout({
    required Product product,
    required ProductUnit unit,
    required ProductPrice price,
    required String configuredBranchId,
    required String saleCurrency,
    required DateTime soldAt,
    required int snapshotPriceMinor,
    required int snapshotBaseQuantityScale,
    required bool snapshotTrackStock,
  }) {
    validateOption(
      product: product,
      unit: unit,
      price: price,
      supportedCurrency: saleCurrency,
    );
    if (product.branchId != configuredBranchId ||
        unit.branchId != configuredBranchId ||
        price.branchId != configuredBranchId) {
      throw const CatalogIntegrityException(
        'Catalog record belongs to another branch',
      );
    }
    if (price.effectiveFrom.isAfter(soldAt) ||
        (price.effectiveTo != null && !price.effectiveTo!.isAfter(soldAt))) {
      throw const CatalogIntegrityException(
        'Price is not effective at sale time',
      );
    }
    if (price.priceMinor != snapshotPriceMinor) {
      throw const CatalogIntegrityException('Cart price snapshot changed');
    }
    if (product.baseQuantityScale != snapshotBaseQuantityScale ||
        product.trackStock != snapshotTrackStock) {
      throw const CatalogIntegrityException('Product stock configuration changed');
    }
  }
}
