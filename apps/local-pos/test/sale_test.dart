import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/sale/cart.dart';
import 'package:auice_pos/features/sale/money_parser.dart';
import 'package:auice_pos/features/sale/sale_completion_service.dart';
import 'package:auice_pos/features/sale/sale_repository.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const branchId = 'branch';
const deviceId = 'device';
final timestamp = DateTime.utc(2026, 7, 14, 10);

Future<void> configure(AppDatabase db) async {
  await db
      .into(db.branches)
      .insert(
        BranchesCompanion.insert(
          id: branchId,
          code: 'BKK01',
          name: 'Bangkok',
          timezone: 'Asia/Bangkok',
          currency: 'THB',
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: timestamp,
        ),
      );
  await db
      .into(db.appMetadata)
      .insert(
        AppMetadataCompanion.insert(
          key: 'device_id',
          value: deviceId,
          updatedAt: timestamp,
        ),
      );
  await ShiftService(db).ensureDevelopmentShift(branchId, deviceId);
}

Future<(Product, ProductUnit, ProductPrice)> option(
  AppDatabase db, {
  required String productId,
  required String unitId,
  required String name,
  required String unitName,
  required int price,
  required int conversion,
  bool trackStock = true,
  String? barcode,
}) async {
  var product = await (db.select(
    db.products,
  )..where((row) => row.id.equals(productId))).getSingleOrNull();
  if (product == null) {
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            id: productId,
            branchId: branchId,
            sku: Value(productId.toUpperCase()),
            name: name,
            baseUnitId: Value(unitId),
            trackStock: trackStock,
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: timestamp,
          ),
        );
    product = await (db.select(
      db.products,
    )..where((row) => row.id.equals(productId))).getSingle();
  }
  await db
      .into(db.productUnits)
      .insert(
        ProductUnitsCompanion.insert(
          id: unitId,
          branchId: branchId,
          productId: productId,
          code: unitId,
          name: unitName,
          unitCategory: 'count',
          isBaseUnit: conversion == 1,
          conversionNumerator: conversion,
          conversionDenominator: 1,
          barcode: Value(barcode),
          allowSale: true,
          allowPurchase: true,
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: timestamp,
        ),
      );
  final priceId = 'price-$unitId';
  await db
      .into(db.productPrices)
      .insert(
        ProductPricesCompanion.insert(
          id: priceId,
          branchId: branchId,
          productId: productId,
          productUnitId: unitId,
          priceMinor: price,
          currency: 'THB',
          effectiveFrom: DateTime.utc(2026),
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: timestamp,
        ),
      );
  return (
    product,
    await (db.select(
      db.productUnits,
    )..where((row) => row.id.equals(unitId))).getSingle(),
    await (db.select(
      db.productPrices,
    )..where((row) => row.id.equals(priceId))).getSingle(),
  );
}

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await configure(db);
  });
  tearDown(() => db.close());

  test(
    'cart merges same unit, separates units, updates, removes, and uses line count',
    () async {
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final caseUnit = await option(
        db,
        productId: 'beer',
        unitId: 'case',
        name: 'Beer',
        unitName: 'Case',
        price: 72000,
        conversion: 12,
      );
      final cart = CartController();
      expect(cart.state.totalMinor, 0);
      cart.add(bottle.$1, bottle.$2, bottle.$3);
      cart.add(bottle.$1, bottle.$2, bottle.$3);
      cart.add(caseUnit.$1, caseUnit.$2, caseUnit.$3);
      expect(cart.state.items, hasLength(2));
      expect(cart.state.itemCount, 2);
      expect(cart.state.totalMinor, 85000);
      cart.setQuantity('bottle', 3);
      expect(cart.state.totalMinor, 91500);
      cart.remove('case');
      expect(cart.state.totalMinor, 19500);
      cart.setQuantity('bottle', 0);
      expect(cart.state.items, isEmpty);
    },
  );

  test(
    'cart rejects invalid and non-exact integer line calculations',
    () async {
      final item = await option(
        db,
        productId: 'weighted',
        unitId: 'half',
        name: 'Weighted',
        unitName: 'Half',
        price: 101,
        conversion: 1,
      );
      expect(
        () => CartItem(
          product: item.$1,
          unit: item.$2,
          price: item.$3,
          quantityMinor: 1,
          quantityScale: 2,
        ),
        throwsStateError,
      );
      expect(
        () => CartItem(
          product: item.$1,
          unit: item.$2,
          price: item.$3,
          quantityMinor: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test('beer scenario totals 1635 THB and moves -3 and -24 bottles', () async {
    final bottle = await option(
      db,
      productId: 'beer',
      unitId: 'bottle',
      name: 'Beer A',
      unitName: 'Bottle',
      price: 6500,
      conversion: 1,
    );
    final caseUnit = await option(
      db,
      productId: 'beer',
      unitId: 'case',
      name: 'Beer A',
      unitName: 'Case',
      price: 72000,
      conversion: 12,
    );
    final cart = CartController();
    cart.add(bottle.$1, bottle.$2, bottle.$3);
    cart.setQuantity('bottle', 3);
    cart.add(caseUnit.$1, caseUnit.$2, caseUnit.$3);
    cart.setQuantity('case', 2);
    final receipt = await SaleCompletionService(
      db,
      now: () => timestamp,
    ).completeCashSale(cart.state, 170000);
    expect(receipt.sale.totalMinor, 163500);
    expect(receipt.sale.changeMinor, 6500);
    expect(
      receipt.movements.map((row) => row.baseQuantityMinor),
      containsAll([-3, -24]),
    );
    expect(await db.select(db.syncOutbox).get(), hasLength(3));
  });

  test('snack units calculate totals and negative base movements', () async {
    final small = await option(
      db,
      productId: 'snack',
      unitId: 'small',
      name: 'Snack',
      unitName: 'Small',
      price: 1000,
      conversion: 1,
    );
    final large = await option(
      db,
      productId: 'snack',
      unitId: 'large',
      name: 'Snack',
      unitName: 'Large',
      price: 5500,
      conversion: 6,
    );
    final box = await option(
      db,
      productId: 'snack',
      unitId: 'box',
      name: 'Snack',
      unitName: 'Box',
      price: 20000,
      conversion: 24,
    );
    final cart = CartController();
    cart.add(small.$1, small.$2, small.$3);
    cart.add(large.$1, large.$2, large.$3);
    cart.add(box.$1, box.$2, box.$3);
    final receipt = await SaleCompletionService(
      db,
      now: () => timestamp,
    ).completeCashSale(cart.state, 30000);
    expect(receipt.sale.totalMinor, 26500);
    expect(
      receipt.movements.map((row) => row.baseQuantityMinor),
      containsAll([-1, -6, -24]),
    );
  });

  test(
    'cash parsing, exact cash, change, insufficient and empty cart',
    () async {
      expect(MoneyParser.parseMinor('200'), 20000);
      expect(MoneyParser.parseMinor('195.50'), 19550);
      expect(() => MoneyParser.parseMinor('1.234'), throwsFormatException);
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
      final exact = await SaleCompletionService(
        db,
        now: () => timestamp,
      ).completeCashSale(cart.state, 6500);
      expect(exact.sale.changeMinor, 0);
      expect(
        () => SaleCompletionService(db).completeCashSale(cart.state, 6400),
        throwsA(isA<SaleException>()),
      );
      expect(
        () =>
            SaleCompletionService(db).completeCashSale(const CartState(), 100),
        throwsA(isA<SaleException>()),
      );
    },
  );

  test(
    'payment, stock, and outbox failures roll back every record and sequence',
    () async {
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
      for (final point in SaleFailurePoint.values) {
        final service = SaleCompletionService(
          db,
          now: () => timestamp,
          failureHook: (current) {
            if (current == point) throw StateError('forced');
          },
        );
        await expectLater(
          service.completeCashSale(cart.state, 6500),
          throwsA(isA<SaleException>()),
        );
        expect(await db.select(db.sales).get(), isEmpty);
        expect(await db.select(db.saleItems).get(), isEmpty);
        expect(await db.select(db.payments).get(), isEmpty);
        expect(await db.select(db.stockMovements).get(), isEmpty);
        expect(await db.select(db.syncOutbox).get(), isEmpty);
        expect(await db.select(db.receiptSequences).get(), isEmpty);
      }
    },
  );

  test('checkout clears cart only after successful persistence', () async {
    final bottle = await option(
      db,
      productId: 'beer',
      unitId: 'bottle',
      name: 'Beer',
      unitName: 'Bottle',
      price: 6500,
      conversion: 1,
    );
    final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
    final failed = CheckoutController(
      SaleCompletionService(db, failureHook: (_) => throw StateError('forced')),
      cart,
    );
    await expectLater(failed.completeCash(6500), throwsA(isA<SaleException>()));
    expect(cart.state.items, hasLength(1));
    final successful = CheckoutController(
      SaleCompletionService(db, now: () => timestamp),
      cart,
    );
    await successful.completeCash(6500);
    expect(cart.state.items, isEmpty);
  });

  test(
    'receipt numbers are sequential and rollback does not consume one',
    () async {
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
      final first = await SaleCompletionService(
        db,
        now: () => timestamp,
      ).completeCashSale(cart.state, 6500);
      final second = await SaleCompletionService(
        db,
        now: () => timestamp,
      ).completeCashSale(cart.state, 6500);
      expect(first.sale.receiptNumber, endsWith('000001'));
      expect(second.sale.receiptNumber, endsWith('000002'));
      expect(first.sale.receiptNumber, isNot(second.sale.receiptNumber));
      final nextDay = await SaleCompletionService(
        db,
        now: () => timestamp.add(const Duration(days: 1)),
      ).completeCashSale(cart.state, 6500);
      expect(nextDay.sale.receiptNumber, startsWith('20260715-'));
      expect(nextDay.sale.receiptNumber, endsWith('000001'));
    },
  );

  test(
    'parallel completions serialize receipt sequences without duplicates',
    () async {
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
      final receipts = await Future.wait([
        SaleCompletionService(
          db,
          now: () => timestamp,
        ).completeCashSale(cart.state, 6500),
        SaleCompletionService(
          db,
          now: () => timestamp,
        ).completeCashSale(cart.state, 6500),
      ]);
      expect(
        receipts.map((row) => row.sale.receiptNumber).toSet(),
        hasLength(2),
      );
    },
  );

  test(
    'repository reopens immutable snapshot and orders recent receipts',
    () async {
      final bottle = await option(
        db,
        productId: 'beer',
        unitId: 'bottle',
        name: 'Historical Beer',
        unitName: 'Bottle',
        price: 6500,
        conversion: 1,
      );
      final cart = CartController()..add(bottle.$1, bottle.$2, bottle.$3);
      final first = await SaleCompletionService(
        db,
        now: () => timestamp,
      ).completeCashSale(cart.state, 6500);
      final later = await SaleCompletionService(
        db,
        now: () => timestamp.add(const Duration(minutes: 1)),
      ).completeCashSale(cart.state, 6500);
      await (db.update(db.products)..where((row) => row.id.equals('beer')))
          .write(const ProductsCompanion(name: Value('Renamed')));
      final repository = SaleRepository(db);
      expect((await repository.getSaleById(first.sale.id))?.id, first.sale.id);
      expect(
        (await repository.getSaleByReceiptNumber(first.sale.receiptNumber))?.id,
        first.sale.id,
      );
      expect(
        (await repository.getReceipt(
          first.sale.id,
        ))?.items.single.productNameSnapshot,
        'Historical Beer',
      );
      expect((await repository.listRecentSales()).first.id, later.sale.id);
      expect(await repository.isSyncPending(first.sale.id), isTrue);
    },
  );
}
