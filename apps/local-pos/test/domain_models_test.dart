import 'package:auice_pos/core/domain/domain_models.dart';
import 'package:auice_pos/core/domain/unit_conversion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart sync types include cash movements', () {
    expect(syncEntityTypes, contains('cash_movement'));
  });
  final at = DateTime.utc(2026, 7, 12, 10, 30);
  const id = '018f6f62-4b1d-7000-8000-000000000001';
  test('Money JSON uses integer minor units and THB', () {
    final value = Money(amountMinor: 6500);
    expect(Money.fromJson(value.toJson()).amountMinor, 6500);
    expect(() => Money(amountMinor: -1), throwsArgumentError);
    expect(() => Money(amountMinor: 1, currency: 'USD'), throwsArgumentError);
  });
  test('Beer receiving and sale conversions', () {
    expect(
      UnitConversion.toBaseMinor(
        quantityMinor: 10,
        quantityScale: 1,
        conversionNumerator: 12,
        conversionDenominator: 1,
        baseQuantityScale: 1,
      ),
      120,
    );
    expect(UnitConversion.signedForMovement('purchase', 120), 120);
    expect(UnitConversion.signedForMovement('sale', 3), -3);
    expect(
      UnitConversion.signedForMovement(
        'sale',
        UnitConversion.toBaseMinor(
          quantityMinor: 2,
          quantityScale: 1,
          conversionNumerator: 12,
          conversionDenominator: 1,
          baseQuantityScale: 1,
        ),
      ),
      -24,
    );
    expect(2 * 72000, 144000);
  });
  test('Snack unit conversions', () {
    expect(
      UnitConversion.toBaseMinor(
        quantityMinor: 5,
        quantityScale: 1,
        conversionNumerator: 24,
        conversionDenominator: 1,
        baseQuantityScale: 1,
      ),
      120,
    );
    expect(
      UnitConversion.signedForMovement(
        'sale',
        UnitConversion.toBaseMinor(
          quantityMinor: 2,
          quantityScale: 1,
          conversionNumerator: 6,
          conversionDenominator: 1,
          baseQuantityScale: 1,
        ),
      ),
      -12,
    );
    expect(UnitConversion.signedForMovement('sale', 3), -3);
  });
  test('invalid and inexact conversions fail', () {
    expect(
      () => UnitConversion.toBaseMinor(
        quantityMinor: 1,
        quantityScale: 1,
        conversionNumerator: 1,
        conversionDenominator: 0,
        baseQuantityScale: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => UnitConversion.toBaseMinor(
        quantityMinor: 1,
        quantityScale: 1,
        conversionNumerator: -1,
        conversionDenominator: 1,
        baseQuantityScale: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => UnitConversion.toBaseMinor(
        quantityMinor: 1,
        quantityScale: 1,
        conversionNumerator: 1,
        conversionDenominator: 2,
        baseQuantityScale: 1,
      ),
      throwsStateError,
    );
  });
  test('scaled weight and length conversions', () {
    expect(
      UnitConversion.toBaseMinor(
        quantityMinor: 1500,
        quantityScale: 1000,
        conversionNumerator: 1000,
        conversionDenominator: 1,
        baseQuantityScale: 1,
      ),
      1500,
    );
    expect(
      UnitConversion.toBaseMinor(
        quantityMinor: 1,
        quantityScale: 1,
        conversionNumerator: 2500,
        conversionDenominator: 1000,
        baseQuantityScale: 1000,
      ),
      2500,
    );
  });
  test('Sale snapshots serialize without current ProductUnit coupling', () {
    final item = SaleItem(
      id: id,
      saleId: id,
      productId: id,
      productUnitId: id,
      productNameSnapshot: 'Beer A',
      unitCodeSnapshot: 'case',
      unitNameSnapshot: 'ลัง',
      quantityMinor: 2,
      quantityScale: 1,
      conversionNumeratorSnapshot: 12,
      conversionDenominatorSnapshot: 1,
      baseQuantityMinor: 24,
      baseQuantityScale: 1,
      unitPriceMinor: 72000,
      subtotalMinor: 144000,
      discountMinor: 0,
      taxMinor: 0,
      totalMinor: 144000,
      createdAt: at,
    );
    final sale = Sale(
      id: id,
      branchId: id,
      deviceId: id,
      shiftId: id,
      receiptNumber: 'R1',
      status: 'completed',
      currency: 'THB',
      subtotalMinor: 144000,
      discountMinor: 0,
      taxMinor: 0,
      totalMinor: 144000,
      paidMinor: 144000,
      changeMinor: 0,
      itemCount: 2,
      soldAt: at,
      items: [item],
      payments: const [],
      createdAt: at,
      updatedAt: at,
      version: 1,
    );
    final restored = Sale.fromJson(sale.toJson());
    expect(restored.items.single.conversionNumeratorSnapshot, 12);
    expect(restored.items.single.unitNameSnapshot, 'ลัง');
    expect(restored.totalMinor, 144000);
  });
  test('Sync event and push request serialize', () {
    final event = SyncEvent(
      id: id,
      branchId: id,
      deviceId: id,
      entityType: 'product_unit',
      entityId: id,
      operation: 'create',
      entityVersion: 1,
      payload: {'name': 'ลัง'},
      occurredAt: at,
      createdAt: at,
      status: 'pending',
      retryCount: 0,
    );
    final restored = SyncEvent.fromJson(event.toJson());
    expect(restored.entityType, 'product_unit');
    final push = SyncPushRequest(branchId: id, deviceId: id, events: [event]);
    expect(push.toJson()['protocolVersion'], 1);
    expect(push.encode(), contains('product_unit'));
  });
}
