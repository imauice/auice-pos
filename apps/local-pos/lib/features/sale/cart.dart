import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/core/domain/unit_conversion.dart';
import 'package:auice_pos/features/sale/catalog_integrity_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class CartItem {
  CartItem({
    required this.product,
    required this.unit,
    required this.price,
    required this.quantityMinor,
    this.quantityScale = 1,
  }) {
    if (quantityMinor <= 0 || quantityScale <= 0) {
      throw ArgumentError('Invalid quantity');
    }
    if (quantityMinor * price.priceMinor % quantityScale != 0) {
      throw StateError('Non-exact line calculation');
    }
    UnitConversion.toBaseMinor(
      quantityMinor: quantityMinor,
      quantityScale: quantityScale,
      conversionNumerator: unit.conversionNumerator,
      conversionDenominator: unit.conversionDenominator,
      baseQuantityScale: product.baseQuantityScale,
    );
  }
  final Product product;
  final ProductUnit unit;
  final ProductPrice price;
  final int quantityMinor;
  final int quantityScale;
  int get subtotalMinor => quantityMinor * price.priceMinor ~/ quantityScale;
  int get discountMinor => 0;
  int get taxMinor => 0;
  int get totalMinor => subtotalMinor;
  int get baseQuantityMinor => UnitConversion.toBaseMinor(
    quantityMinor: quantityMinor,
    quantityScale: quantityScale,
    conversionNumerator: unit.conversionNumerator,
    conversionDenominator: unit.conversionDenominator,
    baseQuantityScale: product.baseQuantityScale,
  );
  CartItem withQuantity(int minor, {int? scale}) => CartItem(
    product: product,
    unit: unit,
    price: price,
    quantityMinor: minor,
    quantityScale: scale ?? quantityScale,
  );
}

@immutable
class CartState {
  const CartState([this.items = const []]);
  final List<CartItem> items;
  int get subtotalMinor =>
      items.fold(0, (sum, item) => sum + item.subtotalMinor);
  int get discountMinor => 0;
  int get taxMinor => 0;
  int get totalMinor => subtotalMinor;
  int get itemCount => items.length;
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());
  CartState get current => state;
  void add(Product product, ProductUnit unit, ProductPrice price) {
    CatalogIntegrityValidator.validateOption(
      product: product,
      unit: unit,
      price: price,
    );
    final index = state.items.indexWhere((item) => item.unit.id == unit.id);
    if (index < 0) {
      state = CartState([
        ...state.items,
        CartItem(product: product, unit: unit, price: price, quantityMinor: 1),
      ]);
      return;
    }
    final items = [...state.items];
    final existing = items[index];
    items[index] = existing.withQuantity(
      existing.quantityMinor + existing.quantityScale,
    );
    state = CartState(items);
  }

  void setQuantity(String unitId, int quantityMinor, {int quantityScale = 1}) {
    if (quantityMinor < 0 || quantityScale <= 0) {
      throw ArgumentError('Invalid quantity');
    }
    if (quantityMinor == 0) return remove(unitId);
    state = CartState([
      for (final item in state.items)
        if (item.unit.id == unitId)
          item.withQuantity(quantityMinor, scale: quantityScale)
        else
          item,
    ]);
  }

  void remove(String unitId) => state = CartState(
    state.items.where((item) => item.unit.id != unitId).toList(),
  );
  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);
