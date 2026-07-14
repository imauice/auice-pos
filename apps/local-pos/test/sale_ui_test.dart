import 'package:auice_pos/app/app.dart';
import 'package:auice_pos/core/catalog/catalog_gateway.dart';
import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class OfflineGateway implements CatalogGateway {
  @override
  Future<bool> isOnline() async => false;
  @override
  Future<Map<String, dynamic>> fetchBranch(String branchId) =>
      throw UnimplementedError();
  @override
  Future<CatalogPage> pull({
    required String branchId,
    required int fromVersion,
    String? cursor,
  }) => throw UnimplementedError();
  @override
  Future<RegistrationResult> register(String deviceId) =>
      throw UnimplementedError();
}

Future<void> seedUi(AppDatabase db) async {
  final now = DateTime.utc(2026, 7, 14);
  await db
      .into(db.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          code: 'BKK01',
          name: 'Bangkok Shop',
          timezone: 'Asia/Bangkok',
          currency: 'THB',
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: now,
        ),
      );
  await db
      .into(db.appMetadata)
      .insert(
        AppMetadataCompanion.insert(
          key: 'device_id',
          value: 'device',
          updatedAt: now,
        ),
      );
  await db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          id: 'beer',
          branchId: 'branch',
          sku: const Value('BEER'),
          name: 'Beer A',
          baseUnitId: const Value('bottle'),
          trackStock: true,
          active: true,
          version: 1,
          catalogVersion: 1,
          updatedAt: now,
        ),
      );
  for (final data in [
    ('bottle', 'Bottle', '111', 1, 6500),
    ('case', 'Case', '222', 12, 72000),
  ]) {
    await db
        .into(db.productUnits)
        .insert(
          ProductUnitsCompanion.insert(
            id: data.$1,
            branchId: 'branch',
            productId: 'beer',
            code: data.$1,
            name: data.$2,
            unitCategory: 'count',
            isBaseUnit: data.$4 == 1,
            conversionNumerator: data.$4,
            conversionDenominator: 1,
            barcode: Value(data.$3),
            allowSale: true,
            allowPurchase: true,
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: now,
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            id: 'price-${data.$1}',
            branchId: 'branch',
            productId: 'beer',
            productUnitId: data.$1,
            priceMinor: data.$5,
            currency: 'THB',
            effectiveFrom: DateTime.utc(2026),
            active: true,
            version: 1,
            catalogVersion: 1,
            updatedAt: now,
          ),
        );
  }
}

void main() {
  testWidgets(
    'barcode checkout, payment error, receipt, and history work offline',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await seedUi(db);
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            catalogGatewayProvider.overrideWithValue(OfflineGateway()),
          ],
          child: const AuicePosApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Sale'));
      await tester.pumpAndSettle();
      expect(find.text('Sale'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '111');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('Bottle • 65.00 THB'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.textContaining('Bottle • 1/1'), findsOneWidget);
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Cash Payment'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.text('Payment insufficient'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '70');
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receipt-number')), findsOneWidget);
      expect(find.text('Change: 5.00 THB'), findsOneWidget);
      expect(find.text('Sync: Pending'), findsOneWidget);

      await tester.tap(find.text('New sale'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.receipt_long));
      await tester.pumpAndSettle();
      expect(find.text('Sale History'), findsOneWidget);
      expect(find.textContaining('Sync pending'), findsOneWidget);
    },
  );
}
