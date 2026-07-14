import 'dart:convert';
import 'package:auice_pos/config/app_config.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/core/domain/unit_conversion.dart';
import 'package:auice_pos/features/sale/cart.dart';
import 'package:auice_pos/features/sale/sale_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class SaleException implements Exception {
  const SaleException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum SaleFailurePoint { payment, stockMovement, outbox }

typedef SaleFailureHook = void Function(SaleFailurePoint point);

class SaleCompletionService {
  SaleCompletionService(this.db, {this.failureHook, this.now = DateTime.now});
  final AppDatabase db;
  final SaleFailureHook? failureHook;
  final DateTime Function() now;

  Future<ReceiptData> completeCashSale(CartState cart, int paidMinor) async {
    if (cart.items.isEmpty) throw const SaleException('Empty cart');
    if (cart.totalMinor <= 0) {
      throw const SaleException('Zero-total sales are not supported');
    }
    if (paidMinor < cart.totalMinor) {
      throw const SaleException('Payment insufficient');
    }
    try {
      return await db.transaction(() async {
        final branch = await db.select(db.branches).getSingleOrNull();
        final device = await (db.select(
          db.appMetadata,
        )..where((row) => row.key.equals('device_id'))).getSingleOrNull();
        if (branch == null || device == null) {
          throw const SaleException('Branch or device is not configured');
        }
        final shift =
            await (db.select(db.shifts)..where(
                  (row) =>
                      row.deviceId.equals(device.value) &
                      row.status.equals('open'),
                ))
                .getSingleOrNull();
        if (shift == null) throw const SaleException('No open shift');
        await _validateCatalog(cart);
        final at = now().toUtc();
        final saleId = const Uuid().v7();
        final receiptNumber = await _nextReceipt(device.value, at);
        final sale = SalesCompanion.insert(
          id: saleId,
          branchId: branch.id,
          deviceId: device.value,
          shiftId: shift.id,
          receiptNumber: receiptNumber,
          status: 'completed',
          currency: 'THB',
          subtotalMinor: cart.subtotalMinor,
          discountMinor: cart.discountMinor,
          taxMinor: cart.taxMinor,
          totalMinor: cart.totalMinor,
          paidMinor: paidMinor,
          changeMinor: paidMinor - cart.totalMinor,
          itemCount: cart.itemCount,
          soldAt: at,
          createdAt: at,
          updatedAt: at,
          version: 1,
        );
        await db.into(db.sales).insert(sale);
        final itemPayloads = <Map<String, dynamic>>[];
        for (final item in cart.items) {
          final itemId = const Uuid().v7();
          final itemPayload = <String, dynamic>{
            'id': itemId,
            'saleId': saleId,
            'productId': item.product.id,
            'productUnitId': item.unit.id,
            'productNameSnapshot': item.product.name,
            'skuSnapshot': item.product.sku,
            'unitCodeSnapshot': item.unit.code,
            'unitNameSnapshot': item.unit.name,
            'barcodeSnapshot': item.unit.barcode,
            'quantityMinor': item.quantityMinor,
            'quantityScale': item.quantityScale,
            'conversionNumeratorSnapshot': item.unit.conversionNumerator,
            'conversionDenominatorSnapshot': item.unit.conversionDenominator,
            'baseQuantityMinor': item.baseQuantityMinor,
            'baseQuantityScale': item.quantityScale,
            'unitPriceMinor': item.price.priceMinor,
            'subtotalMinor': item.subtotalMinor,
            'discountMinor': 0,
            'taxMinor': 0,
            'totalMinor': item.totalMinor,
            'createdAt': at.toIso8601String(),
          };
          itemPayloads.add(itemPayload);
          await db
              .into(db.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  id: itemId,
                  saleId: saleId,
                  productId: item.product.id,
                  productUnitId: item.unit.id,
                  productNameSnapshot: item.product.name,
                  skuSnapshot: Value(item.product.sku),
                  unitCodeSnapshot: item.unit.code,
                  unitNameSnapshot: item.unit.name,
                  barcodeSnapshot: Value(item.unit.barcode),
                  quantityMinor: item.quantityMinor,
                  quantityScale: item.quantityScale,
                  conversionNumeratorSnapshot: item.unit.conversionNumerator,
                  conversionDenominatorSnapshot:
                      item.unit.conversionDenominator,
                  baseQuantityMinor: item.baseQuantityMinor,
                  baseQuantityScale: item.quantityScale,
                  unitPriceMinor: item.price.priceMinor,
                  subtotalMinor: item.subtotalMinor,
                  discountMinor: 0,
                  taxMinor: 0,
                  totalMinor: item.totalMinor,
                  createdAt: at,
                ),
              );
          if (item.product.trackStock) {
            failureHook?.call(SaleFailurePoint.stockMovement);
            final movementId = const Uuid().v7();
            await db
                .into(db.stockMovements)
                .insert(
                  StockMovementsCompanion.insert(
                    id: movementId,
                    branchId: branch.id,
                    deviceId: device.value,
                    productId: item.product.id,
                    type: 'sale',
                    sourceUnitId: item.unit.id,
                    sourceUnitCodeSnapshot: item.unit.code,
                    sourceUnitNameSnapshot: item.unit.name,
                    sourceQuantityMinor: item.quantityMinor,
                    sourceQuantityScale: item.quantityScale,
                    conversionNumeratorSnapshot: item.unit.conversionNumerator,
                    conversionDenominatorSnapshot:
                        item.unit.conversionDenominator,
                    baseQuantityMinor: UnitConversion.signedForMovement(
                      'sale',
                      item.baseQuantityMinor,
                    ),
                    baseQuantityScale: item.quantityScale,
                    referenceType: 'sale',
                    referenceId: saleId,
                    occurredAt: at,
                    createdAt: at,
                    version: 1,
                  ),
                );
          }
        }
        failureHook?.call(SaleFailurePoint.payment);
        final paymentId = const Uuid().v7();
        final paymentPayload = <String, dynamic>{
          'id': paymentId,
          'saleId': saleId,
          'branchId': branch.id,
          'deviceId': device.value,
          'method': 'cash',
          'amountMinor': paidMinor,
          'currency': 'THB',
          'reference': null,
          'paidAt': at.toIso8601String(),
          'createdAt': at.toIso8601String(),
        };
        await db
            .into(db.payments)
            .insert(
              PaymentsCompanion.insert(
                id: paymentId,
                saleId: saleId,
                branchId: branch.id,
                deviceId: device.value,
                method: 'cash',
                amountMinor: paidMinor,
                currency: 'THB',
                paidAt: at,
                createdAt: at,
              ),
            );
        final salePayload = <String, dynamic>{
          'id': saleId,
          'branchId': branch.id,
          'deviceId': device.value,
          'shiftId': shift.id,
          'receiptNumber': receiptNumber,
          'status': 'completed',
          'currency': 'THB',
          'subtotalMinor': cart.subtotalMinor,
          'discountMinor': 0,
          'taxMinor': 0,
          'totalMinor': cart.totalMinor,
          'paidMinor': paidMinor,
          'changeMinor': paidMinor - cart.totalMinor,
          'itemCount': cart.itemCount,
          'soldAt': at.toIso8601String(),
          'voidedAt': null,
          'voidReason': null,
          'items': itemPayloads,
          'payments': [paymentPayload],
          'createdAt': at.toIso8601String(),
          'updatedAt': at.toIso8601String(),
          'version': 1,
          'deletedAt': null,
        };
        failureHook?.call(SaleFailurePoint.outbox);
        await _outbox(branch.id, device.value, 'sale', saleId, salePayload, at);
        final movements =
            await (db.select(db.stockMovements)..where(
                  (row) =>
                      row.referenceType.equals('sale') &
                      row.referenceId.equals(saleId),
                ))
                .get();
        for (final movement in movements) {
          failureHook?.call(SaleFailurePoint.outbox);
          await _outbox(
            branch.id,
            device.value,
            'stock_movement',
            movement.id,
            _movementJson(movement),
            at,
          );
        }
        final storedSale = await (db.select(
          db.sales,
        )..where((row) => row.id.equals(saleId))).getSingle();
        return ReceiptData(
          sale: storedSale,
          branchName: branch.name,
          items: await (db.select(
            db.saleItems,
          )..where((row) => row.saleId.equals(saleId))).get(),
          payments: await (db.select(
            db.payments,
          )..where((row) => row.saleId.equals(saleId))).get(),
          movements: movements,
        );
      });
    } on SaleException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Sale completion rolled back: $error\n$stackTrace');
      throw const SaleException('Database transaction failure');
    }
  }

  Future<void> _validateCatalog(CartState cart) async {
    for (final item in cart.items) {
      final product =
          await (db.select(db.products)..where(
                (row) =>
                    row.id.equals(item.product.id) &
                    row.active.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (product == null) throw const SaleException('Product unavailable');
      final unit =
          await (db.select(db.productUnits)..where(
                (row) =>
                    row.id.equals(item.unit.id) &
                    row.active.equals(true) &
                    row.allowSale.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (unit == null) throw const SaleException('Product unit unavailable');
      final price =
          await (db.select(db.productPrices)..where(
                (row) =>
                    row.id.equals(item.price.id) &
                    row.active.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (price == null || price.priceMinor != item.price.priceMinor) {
        throw const SaleException('Price unavailable');
      }
    }
  }

  Future<String> _nextReceipt(String deviceId, DateTime at) async {
    final date =
        '${at.year.toString().padLeft(4, '0')}${at.month.toString().padLeft(2, '0')}${at.day.toString().padLeft(2, '0')}';
    final row =
        await (db.select(db.receiptSequences)..where(
              (r) => r.deviceId.equals(deviceId) & r.localDate.equals(date),
            ))
            .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await db
        .into(db.receiptSequences)
        .insertOnConflictUpdate(
          ReceiptSequencesCompanion.insert(
            deviceId: deviceId,
            localDate: date,
            nextValue: value + 1,
          ),
        );
    final configured = AppConfig.current.deviceName
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .padRight(5, '0')
        .substring(0, 5);
    final identity = deviceId
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .padLeft(4, '0');
    final code = '$configured${identity.substring(identity.length - 4)}';
    return '$date-$code-${value.toString().padLeft(6, '0')}';
  }

  Future<void> _outbox(
    String branchId,
    String deviceId,
    String type,
    String id,
    Map<String, dynamic> payload,
    DateTime at,
  ) => db
      .into(db.syncOutbox)
      .insert(
        SyncOutboxCompanion.insert(
          id: const Uuid().v7(),
          branchId: branchId,
          deviceId: deviceId,
          entityType: type,
          entityId: id,
          operation: 'append',
          entityVersion: 1,
          payloadJson: jsonEncode(payload),
          occurredAt: at,
          createdAt: at,
        ),
      );
  Map<String, dynamic> _movementJson(StockMovement movement) => {
    'id': movement.id,
    'branchId': movement.branchId,
    'deviceId': movement.deviceId,
    'productId': movement.productId,
    'type': movement.type,
    'sourceUnitId': movement.sourceUnitId,
    'sourceUnitCodeSnapshot': movement.sourceUnitCodeSnapshot,
    'sourceUnitNameSnapshot': movement.sourceUnitNameSnapshot,
    'sourceQuantityMinor': movement.sourceQuantityMinor,
    'sourceQuantityScale': movement.sourceQuantityScale,
    'conversionNumeratorSnapshot': movement.conversionNumeratorSnapshot,
    'conversionDenominatorSnapshot': movement.conversionDenominatorSnapshot,
    'baseQuantityMinor': movement.baseQuantityMinor,
    'baseQuantityScale': movement.baseQuantityScale,
    'referenceType': movement.referenceType,
    'referenceId': movement.referenceId,
    'occurredAt': movement.occurredAt.toIso8601String(),
    'note': movement.note,
    'createdAt': movement.createdAt.toIso8601String(),
    'version': 1,
  };
}

final saleCompletionServiceProvider = Provider<SaleCompletionService>(
  (ref) => SaleCompletionService(ref.watch(databaseProvider)),
);

class CheckoutController {
  CheckoutController(this.service, this.cart);
  final SaleCompletionService service;
  final CartController cart;
  Future<ReceiptData> completeCash(int paidMinor) async {
    final receipt = await service.completeCashSale(cart.current, paidMinor);
    cart.clear();
    return receipt;
  }
}

final checkoutControllerProvider = Provider<CheckoutController>(
  (ref) => CheckoutController(
    ref.watch(saleCompletionServiceProvider),
    ref.read(cartProvider.notifier),
  ),
);
