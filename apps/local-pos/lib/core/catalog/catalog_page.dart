class CatalogPage {
  const CatalogPage({
    required this.fromVersion,
    required this.targetVersion,
    required this.hasMore,
    this.nextCursor,
    required this.categories,
    required this.products,
    required this.productUnits,
    required this.productPrices,
  });
  final int fromVersion, targetVersion;
  final bool hasMore;
  final String? nextCursor;
  final List<Map<String, dynamic>> categories,
      products,
      productUnits,
      productPrices;
  factory CatalogPage.fromJson(Map<String, dynamic> json) => CatalogPage(
    fromVersion: json['fromVersion'] as int,
    targetVersion: json['targetVersion'] as int,
    hasMore: json['hasMore'] as bool,
    nextCursor: json['nextCursor'] as String?,
    categories: _records(json['categories']),
    products: _records(json['products']),
    productUnits: _records(json['productUnits']),
    productPrices: _records(json['productPrices']),
  );
  static List<Map<String, dynamic>> _records(Object? value) => (value as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}
