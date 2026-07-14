import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/inventory/inventory_service.dart';
import 'package:auice_pos/features/inventory/inventory_screens.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 8, 1);

Future<void> productFixture(
  AppDatabase db, {
  String branch = 'branch',
  String product = 'beer',
  int scale = 1,
  int? threshold,
  String? baseName,
}) async {
  await db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          id: product,
          branchId: branch,
          sku: Value(product.toUpperCase()),
          name: product,
          baseUnitId: Value('$product-base'),
          trackStock: true,
          baseQuantityScale: Value(scale),
          lowStockThresholdMinor: Value(threshold),
          lowStockThresholdScale: Value(threshold == null ? null : scale),
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: now,
        ),
      );
  await db
      .into(db.productUnits)
      .insert(
        ProductUnitsCompanion.insert(
          id: '$product-base',
          branchId: branch,
          productId: product,
          code: 'base',
          name: baseName ?? (scale == 1000 ? 'meter' : 'bottle'),
          unitCategory: scale == 1000 ? 'length' : 'count',
          isBaseUnit: true,
          conversionNumerator: 1,
          conversionDenominator: 1,
          allowSale: true,
          allowPurchase: true,
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: now,
        ),
      );
}

Future<void> unitFixture(
  AppDatabase db, {
  required String id,
  String branch = 'branch',
  String product = 'beer',
  required int conversion,
  bool purchase = true,
  String? name,
}) => db
    .into(db.productUnits)
    .insert(
      ProductUnitsCompanion.insert(
        id: id,
        branchId: branch,
        productId: product,
        code: id,
        name: name ?? id,
        unitCategory: 'count',
        isBaseUnit: false,
        conversionNumerator: conversion,
        conversionDenominator: 1,
        allowSale: true,
        allowPurchase: purchase,
        active: true,
        version: 1,
        catalogVersion: 1,
        updatedAt: now,
      ),
    );

Future<void> rawMovement(
  AppDatabase db, {
  required String id,
  String branch = 'branch',
  String product = 'beer',
  required String type,
  required int base,
  int scale = 1,
  DateTime? at,
}) => db
    .into(db.stockMovements)
    .insert(
      StockMovementsCompanion.insert(
        id: id,
        branchId: branch,
        deviceId: 'device',
        productId: product,
        type: type,
        sourceUnitId: '$product-base',
        sourceUnitCodeSnapshot: 'base',
        sourceUnitNameSnapshot: 'Base snapshot',
        sourceQuantityMinor: base.abs(),
        sourceQuantityScale: scale,
        conversionNumeratorSnapshot: 1,
        conversionDenominatorSnapshot: 1,
        baseQuantityMinor: base,
        baseQuantityScale: scale,
        referenceType: type == 'sale' ? 'sale' : 'test',
        referenceId: id,
        occurredAt: at ?? now,
        createdAt: at ?? now,
        version: 1,
      ),
    );

Future<void> uiConfiguration(AppDatabase db) async {
  await db
      .into(db.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          code: 'BKK',
          name: 'Bangkok',
          timezone: 'Asia/Bangkok',
          currency: 'THB',
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: now,
        ),
      );
  for (final entry in {
    'device_id': 'device',
    'registered_branch_id': 'branch',
    'device_active': 'true',
  }.entries) {
    await db
        .into(db.appMetadata)
        .insert(
          AppMetadataCompanion.insert(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          ),
        );
  }
}

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await productFixture(db);
    await unitFixture(db, id: 'case', conversion: 12, name: 'case');
  });
  tearDown(() => db.close());

  test(
    'balances aggregate movements, preserve negatives, and isolate data',
    () async {
      final balances = StockBalanceService(db);
      expect(
        (await balances.getProductBalance('branch', 'beer')).baseQuantityMinor,
        0,
      );
      for (final movement in [
        ('open', 'opening', 60),
        ('buy', 'purchase', 48),
        ('sale', 'sale', -27),
        ('in', 'adjustment_in', 2),
        ('out', 'adjustment_out', -2),
        ('waste', 'waste', -1),
      ]) {
        await rawMovement(
          db,
          id: movement.$1,
          type: movement.$2,
          base: movement.$3,
        );
      }
      expect(
        (await balances.getProductBalance('branch', 'beer')).baseQuantityMinor,
        80,
      );
      await rawMovement(db, id: 'negative', type: 'sale', base: -100);
      expect(
        (await balances.getProductBalance('branch', 'beer')).baseQuantityMinor,
        -20,
      );
      await productFixture(db, branch: 'other', product: 'other-beer');
      await rawMovement(
        db,
        id: 'other',
        branch: 'other',
        product: 'other-beer',
        type: 'opening',
        base: 99,
      );
      expect(
        (await balances.getProductBalance('branch', 'beer')).baseQuantityMinor,
        -20,
      );
    },
  );

  test('scale mismatch is reported as corruption', () async {
    await rawMovement(db, id: 'bad', type: 'opening', base: 1, scale: 1000);
    expect(
      StockBalanceService(db).getProductBalance('branch', 'beer'),
      throwsA(isA<InventoryException>()),
    );
  });

  test('beer scenario and largest-package display are exact', () async {
    final service = InventoryMovementService(db);
    await service.opening(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'beer',
      productUnitId: 'case',
      quantityMinor: 5,
      quantityScale: 1,
      note: 'initial',
    );
    await rawMovement(db, id: 'sale-bottles', type: 'sale', base: -3);
    await rawMovement(db, id: 'sale-cases', type: 'sale', base: -24);
    await service.receive(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'beer',
      productUnitId: 'case',
      quantityMinor: 4,
      quantityScale: 1,
    );
    await service.adjust(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'beer',
      productUnitId: 'beer-base',
      type: 'waste',
      quantityMinor: 1,
      quantityScale: 1,
      reasonCode: 'damaged',
    );
    final balance = await StockBalanceService(
      db,
    ).getProductBalance('branch', 'beer');
    expect(balance.baseQuantityMinor, 80);
    final display = StockDisplayConversionService().convert(
      balance.baseQuantityMinor,
      await db.select(db.products).getSingle(),
      await db.select(db.productUnits).get(),
    );
    expect(display.label, '6 case + 8 bottle');
    expect(
      StockDisplayConversionService()
          .convert(
            93,
            await db.select(db.products).getSingle(),
            await db.select(db.productUnits).get(),
          )
          .label,
      '7 case + 9 bottle',
    );
    expect(
      StockDisplayConversionService()
          .convert(
            -5,
            await db.select(db.products).getSingle(),
            await db.select(db.productUnits).get(),
          )
          .label,
      '-5 bottle',
    );
  });

  test('snack and measured scenarios retain canonical scale', () async {
    await productFixture(db, product: 'snack', baseName: 'small bag');
    await unitFixture(
      db,
      id: 'box',
      product: 'snack',
      conversion: 24,
      name: 'box',
    );
    await unitFixture(db, id: 'large', product: 'snack', conversion: 6);
    final service = InventoryMovementService(db);
    await service.opening(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'snack',
      productUnitId: 'box',
      quantityMinor: 2,
      quantityScale: 1,
      note: 'initial',
    );
    await service.receive(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'snack',
      productUnitId: 'large',
      quantityMinor: 3,
      quantityScale: 1,
    );
    await rawMovement(
      db,
      id: 'snack-sale',
      product: 'snack',
      type: 'sale',
      base: -5,
    );
    await service.adjust(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'snack',
      productUnitId: 'large',
      type: 'waste',
      quantityMinor: 1,
      quantityScale: 1,
      reasonCode: 'damaged',
    );
    expect(
      (await StockBalanceService(
        db,
      ).getProductBalance('branch', 'snack')).baseQuantityMinor,
      55,
    );
    final snackProduct = await (db.select(
      db.products,
    )..where((p) => p.id.equals('snack'))).getSingle();
    final snackUnits = await (db.select(
      db.productUnits,
    )..where((u) => u.productId.equals('snack'))).get();
    expect(
      StockDisplayConversionService()
          .convert(53, snackProduct, snackUnits)
          .label,
      '2 box + 5 small bag',
    );

    await productFixture(db, product: 'fabric', scale: 1000);
    await service.opening(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'fabric',
      productUnitId: 'fabric-base',
      quantityMinor: 10000,
      quantityScale: 1000,
      note: 'initial',
    );
    await service.adjust(
      branchId: 'branch',
      deviceId: 'device',
      productId: 'fabric',
      productUnitId: 'fabric-base',
      type: 'adjustment_out',
      quantityMinor: 1250,
      quantityScale: 1000,
      reasonCode: 'physical_count',
    );
    final fabric = await StockBalanceService(
      db,
    ).getProductBalance('branch', 'fabric');
    expect(fabric.baseQuantityMinor, 8750);
    expect(fabric.baseQuantityScale, 1000);
    final fabricProduct = await (db.select(
      db.products,
    )..where((p) => p.id.equals('fabric'))).getSingle();
    final fabricUnits = await (db.select(
      db.productUnits,
    )..where((u) => u.productId.equals('fabric'))).get();
    expect(
      StockDisplayConversionService()
          .convert(8750, fabricProduct, fabricUnits)
          .label,
      '8.75 meter',
    );
  });

  test(
    'receiving validates unit and rolls movement and outbox back together',
    () async {
      await unitFixture(db, id: 'disabled', conversion: 1, purchase: false);
      final service = InventoryMovementService(db);
      await expectLater(
        service.receive(
          branchId: 'branch',
          deviceId: 'device',
          productId: 'beer',
          productUnitId: 'disabled',
          quantityMinor: 1,
          quantityScale: 1,
        ),
        throwsA(isA<InventoryException>()),
      );
      final failing = InventoryMovementService(
        db,
        failureHook: (_) => throw StateError('forced'),
      );
      await expectLater(
        failing.receive(
          branchId: 'branch',
          deviceId: 'device',
          productId: 'beer',
          productUnitId: 'case',
          quantityMinor: 1,
          quantityScale: 1,
        ),
        throwsA(isA<InventoryException>()),
      );
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test(
    'receiving rejects wrong product, branch, and inexact conversion',
    () async {
      await productFixture(db, product: 'other-product');
      await unitFixture(
        db,
        id: 'other-unit',
        product: 'other-product',
        conversion: 1,
      );
      await db
          .into(db.productUnits)
          .insert(
            ProductUnitsCompanion.insert(
              id: 'wrong-branch',
              branchId: 'other-branch',
              productId: 'beer',
              code: 'wrong',
              name: 'wrong',
              unitCategory: 'count',
              isBaseUnit: false,
              conversionNumerator: 1,
              conversionDenominator: 1,
              allowSale: true,
              allowPurchase: true,
              active: true,
              version: 1,
              catalogVersion: 1,
              updatedAt: now,
            ),
          );
      await db
          .into(db.productUnits)
          .insert(
            ProductUnitsCompanion.insert(
              id: 'half',
              branchId: 'branch',
              productId: 'beer',
              code: 'half',
              name: 'half',
              unitCategory: 'count',
              isBaseUnit: false,
              conversionNumerator: 1,
              conversionDenominator: 2,
              allowSale: true,
              allowPurchase: true,
              active: true,
              version: 1,
              catalogVersion: 1,
              updatedAt: now,
            ),
          );
      final service = InventoryMovementService(db);
      for (final unit in ['other-unit', 'wrong-branch', 'half']) {
        await expectLater(
          service.receive(
            branchId: 'branch',
            deviceId: 'device',
            productId: 'beer',
            productUnitId: unit,
            quantityMinor: 1,
            quantityScale: 1,
          ),
          throwsA(isA<InventoryException>()),
        );
      }
      expect(await db.select(db.stockMovements).get(), isEmpty);
    },
  );

  test(
    'opening is first-movement only and adjustments validate input',
    () async {
      final service = InventoryMovementService(db);
      await service.opening(
        branchId: 'branch',
        deviceId: 'device',
        productId: 'beer',
        productUnitId: 'case',
        quantityMinor: 1,
        quantityScale: 1,
        note: 'initial',
      );
      await expectLater(
        service.opening(
          branchId: 'branch',
          deviceId: 'device',
          productId: 'beer',
          productUnitId: 'case',
          quantityMinor: 1,
          quantityScale: 1,
          note: 'again',
        ),
        throwsA(isA<InventoryException>()),
      );
      await productFixture(db, product: 'sold-first');
      await rawMovement(
        db,
        id: 'early-sale',
        product: 'sold-first',
        type: 'sale',
        base: -1,
      );
      await expectLater(
        service.opening(
          branchId: 'branch',
          deviceId: 'device',
          productId: 'sold-first',
          productUnitId: 'sold-first-base',
          quantityMinor: 1,
          quantityScale: 1,
          note: 'too late',
        ),
        throwsA(isA<InventoryException>()),
      );
      for (final quantity in [0, -1]) {
        await expectLater(
          service.adjust(
            branchId: 'branch',
            deviceId: 'device',
            productId: 'beer',
            productUnitId: 'case',
            type: 'adjustment_in',
            quantityMinor: quantity,
            quantityScale: 1,
            reasonCode: 'found',
          ),
          throwsA(isA<InventoryException>()),
        );
      }
    },
  );

  test('repository bounds, orders, and filters immutable snapshots', () async {
    await rawMovement(db, id: 'one', type: 'opening', base: 1, at: now);
    await rawMovement(
      db,
      id: 'two',
      type: 'waste',
      base: -1,
      at: now.add(const Duration(hours: 1)),
    );
    final repository = StockMovementRepository(db);
    expect(
      (await repository.listMovementsForBranch('branch', limit: 1)).single.id,
      'two',
    );
    expect(
      (await repository.listMovementsByType('branch', 'waste')).single.id,
      'two',
    );
    expect(
      (await repository.listMovementsByReference('sale', 'missing')),
      isEmpty,
    );
    expect(
      await repository.listMovementsByDateRange(
        'branch',
        now.add(const Duration(minutes: 30)),
        now.add(const Duration(hours: 2)),
      ),
      hasLength(1),
    );
    final ledger = await repository.listLedger('branch');
    expect(ledger.map((row) => row.movementId), ['two', 'one']);
    expect(ledger.first.balanceAfterMovement, 0);
    expect(ledger.last.balanceAfterMovement, 1);
    expect(ledger.first.sourceUnitName, 'Base snapshot');
  });

  test('stock statuses include normal, low, zero, and negative', () async {
    await (db.update(db.products)..where((p) => p.id.equals('beer'))).write(
      const ProductsCompanion(
        lowStockThresholdMinor: Value(5),
        lowStockThresholdScale: Value(1),
      ),
    );
    final service = StockBalanceService(db);
    final product = await db.select(db.products).getSingle();
    expect(service.stockStatus(product, 6), StockStatus.normal);
    expect(service.stockStatus(product, 5), StockStatus.low);
    expect(service.stockStatus(product, 0), StockStatus.outOfStock);
    expect(service.stockStatus(product, -1), StockStatus.negative);
  });

  testWidgets('stock list renders a visible negative warning', (tester) async {
    await uiConfiguration(db);
    await rawMovement(db, id: 'negative-ui', type: 'sale', base: -5);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: StockListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('beer'), findsOneWidget);
    expect(find.textContaining('negative'), findsOneWidget);
    expect(find.textContaining('-5/1'), findsOneWidget);
  });

  testWidgets('receive preview and confirmation work offline', (tester) async {
    await uiConfiguration(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: InventoryMovementScreen(
            branchId: 'branch',
            productId: 'beer',
            type: 'purchase',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('bottle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('case').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('inventory-quantity')), '5');
    await tester.pump();
    expect(find.text('Base quantity: 60'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
      (await db.select(db.stockMovements).getSingle()).baseQuantityMinor,
      60,
    );
    expect(await db.select(db.syncOutbox).get(), hasLength(1));
  });

  testWidgets('waste, ledger filtering, and detail snapshots render offline', (
    tester,
  ) async {
    await uiConfiguration(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: InventoryMovementScreen(
            branchId: 'branch',
            productId: 'beer',
            type: 'waste',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('inventory-quantity')), '1');
    await tester.pump();
    expect(find.text('Base quantity: -1'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    final waste = await db.select(db.stockMovements).getSingle();
    expect(waste.baseQuantityMinor, -1);

    await rawMovement(db, id: 'purchase-ui', type: 'purchase', base: 12);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: StockLedgerScreen(branchId: 'branch')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('waste'), findsOneWidget);
    expect(find.textContaining('purchase'), findsOneWidget);
    await tester.tap(find.text('All types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waste').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('waste'), findsOneWidget);
    expect(find.textContaining('purchase'), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: StockMovementDetailScreen(id: waste.id)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Base: -1/1'), findsOneWidget);
    expect(find.text('Unit snapshot: bottle'), findsOneWidget);
  });
}
