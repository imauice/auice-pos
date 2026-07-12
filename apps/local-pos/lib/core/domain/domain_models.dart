import 'dart:convert';
import 'package:flutter/foundation.dart';

DateTime utc(String value) => DateTime.parse(value).toUtc();
String iso(DateTime value) => value.toUtc().toIso8601String();

@immutable
class Money {
  const Money._(this.amountMinor, this.currency);
  final int amountMinor;
  final String currency;
  factory Money({required int amountMinor, String currency = 'THB'}) {
    if (amountMinor < 0) throw ArgumentError.value(amountMinor);
    if (currency != 'THB') throw ArgumentError.value(currency);
    return Money._(amountMinor, currency);
  }
  factory Money.fromJson(Map<String, dynamic> json) => Money(
    amountMinor: json['amountMinor'] as int,
    currency: json['currency'] as String,
  );
  Map<String, dynamic> toJson() => {
    'amountMinor': amountMinor,
    'currency': currency,
  };
}

@immutable
class Branch {
  const Branch({
    required this.id,
    required this.code,
    required this.name,
    required this.timezone,
    required this.currency,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, code, name, timezone, currency;
  final bool active;
  final DateTime createdAt, updatedAt;
  final int version;
  final DateTime? deletedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'timezone': timezone,
    'currency': currency,
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class Device {
  const Device({
    required this.id,
    required this.branchId,
    required this.code,
    required this.name,
    required this.platform,
    required this.appVersion,
    this.lastSeenAt,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, code, name, platform, appVersion;
  final DateTime? lastSeenAt, deletedAt;
  final bool active;
  final DateTime createdAt, updatedAt;
  final int version;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'code': code,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
    'lastSeenAt': lastSeenAt == null ? null : iso(lastSeenAt!),
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class Category {
  const Category({
    required this.id,
    required this.branchId,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, name;
  final String? description;
  final int sortOrder, version;
  final bool active;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'name': name,
    'description': description,
    'sortOrder': sortOrder,
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class Product {
  const Product({
    required this.id,
    required this.branchId,
    this.categoryId,
    this.sku,
    required this.name,
    this.description,
    this.baseUnitId,
    required this.trackStock,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, name;
  final String? categoryId, sku, description, baseUnitId;
  final bool trackStock, active;
  final DateTime createdAt, updatedAt;
  final int version;
  final DateTime? deletedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'categoryId': categoryId,
    'sku': sku,
    'name': name,
    'description': description,
    'baseUnitId': baseUnitId,
    'trackStock': trackStock,
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class ProductUnit {
  const ProductUnit({
    required this.id,
    required this.branchId,
    required this.productId,
    required this.code,
    required this.name,
    required this.unitCategory,
    required this.isBaseUnit,
    required this.conversionNumerator,
    required this.conversionDenominator,
    this.barcode,
    required this.allowSale,
    required this.allowPurchase,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, productId, code, name, unitCategory;
  final bool isBaseUnit, allowSale, allowPurchase, active;
  final int conversionNumerator, conversionDenominator, version;
  final String? barcode;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'productId': productId,
    'code': code,
    'name': name,
    'unitCategory': unitCategory,
    'isBaseUnit': isBaseUnit,
    'conversionNumerator': conversionNumerator,
    'conversionDenominator': conversionDenominator,
    'barcode': barcode,
    'allowSale': allowSale,
    'allowPurchase': allowPurchase,
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class ProductPrice {
  const ProductPrice({
    required this.id,
    required this.branchId,
    required this.productId,
    required this.productUnitId,
    required this.priceMinor,
    required this.currency,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, productId, productUnitId, currency;
  final int priceMinor, version;
  final DateTime effectiveFrom, createdAt, updatedAt;
  final DateTime? effectiveTo, deletedAt;
  final bool active;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'productId': productId,
    'productUnitId': productUnitId,
    'priceMinor': priceMinor,
    'currency': currency,
    'effectiveFrom': iso(effectiveFrom),
    'effectiveTo': effectiveTo == null ? null : iso(effectiveTo!),
    'active': active,
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productUnitId,
    required this.productNameSnapshot,
    this.skuSnapshot,
    required this.unitCodeSnapshot,
    required this.unitNameSnapshot,
    this.barcodeSnapshot,
    required this.quantityMinor,
    required this.quantityScale,
    required this.conversionNumeratorSnapshot,
    required this.conversionDenominatorSnapshot,
    required this.baseQuantityMinor,
    required this.baseQuantityScale,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.createdAt,
  });
  final String id,
      saleId,
      productId,
      productUnitId,
      productNameSnapshot,
      unitCodeSnapshot,
      unitNameSnapshot;
  final String? skuSnapshot, barcodeSnapshot;
  final int quantityMinor,
      quantityScale,
      conversionNumeratorSnapshot,
      conversionDenominatorSnapshot,
      baseQuantityMinor,
      baseQuantityScale,
      unitPriceMinor,
      subtotalMinor,
      discountMinor,
      taxMinor,
      totalMinor;
  final DateTime createdAt;
  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
    id: j['id'] as String,
    saleId: j['saleId'] as String,
    productId: j['productId'] as String,
    productUnitId: j['productUnitId'] as String,
    productNameSnapshot: j['productNameSnapshot'] as String,
    skuSnapshot: j['skuSnapshot'] as String?,
    unitCodeSnapshot: j['unitCodeSnapshot'] as String,
    unitNameSnapshot: j['unitNameSnapshot'] as String,
    barcodeSnapshot: j['barcodeSnapshot'] as String?,
    quantityMinor: j['quantityMinor'] as int,
    quantityScale: j['quantityScale'] as int,
    conversionNumeratorSnapshot: j['conversionNumeratorSnapshot'] as int,
    conversionDenominatorSnapshot: j['conversionDenominatorSnapshot'] as int,
    baseQuantityMinor: j['baseQuantityMinor'] as int,
    baseQuantityScale: j['baseQuantityScale'] as int,
    unitPriceMinor: j['unitPriceMinor'] as int,
    subtotalMinor: j['subtotalMinor'] as int,
    discountMinor: j['discountMinor'] as int,
    taxMinor: j['taxMinor'] as int,
    totalMinor: j['totalMinor'] as int,
    createdAt: utc(j['createdAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'saleId': saleId,
    'productId': productId,
    'productUnitId': productUnitId,
    'productNameSnapshot': productNameSnapshot,
    'skuSnapshot': skuSnapshot,
    'unitCodeSnapshot': unitCodeSnapshot,
    'unitNameSnapshot': unitNameSnapshot,
    'barcodeSnapshot': barcodeSnapshot,
    'quantityMinor': quantityMinor,
    'quantityScale': quantityScale,
    'conversionNumeratorSnapshot': conversionNumeratorSnapshot,
    'conversionDenominatorSnapshot': conversionDenominatorSnapshot,
    'baseQuantityMinor': baseQuantityMinor,
    'baseQuantityScale': baseQuantityScale,
    'unitPriceMinor': unitPriceMinor,
    'subtotalMinor': subtotalMinor,
    'discountMinor': discountMinor,
    'taxMinor': taxMinor,
    'totalMinor': totalMinor,
    'createdAt': iso(createdAt),
  };
}

@immutable
class Payment {
  const Payment({
    required this.id,
    required this.saleId,
    required this.branchId,
    required this.deviceId,
    required this.method,
    required this.amountMinor,
    required this.currency,
    this.reference,
    required this.paidAt,
    required this.createdAt,
  });
  final String id, saleId, branchId, deviceId, method, currency;
  final String? reference;
  final int amountMinor;
  final DateTime paidAt, createdAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'saleId': saleId,
    'branchId': branchId,
    'deviceId': deviceId,
    'method': method,
    'amountMinor': amountMinor,
    'currency': currency,
    'reference': reference,
    'paidAt': iso(paidAt),
    'createdAt': iso(createdAt),
  };
}

@immutable
class Sale {
  const Sale({
    required this.id,
    required this.branchId,
    required this.deviceId,
    required this.shiftId,
    required this.receiptNumber,
    required this.status,
    required this.currency,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.paidMinor,
    required this.changeMinor,
    required this.itemCount,
    required this.soldAt,
    this.voidedAt,
    this.voidReason,
    required this.items,
    required this.payments,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  final String id, branchId, deviceId, shiftId, receiptNumber, status, currency;
  final int subtotalMinor,
      discountMinor,
      taxMinor,
      totalMinor,
      paidMinor,
      changeMinor,
      itemCount,
      version;
  final DateTime soldAt, createdAt, updatedAt;
  final DateTime? voidedAt, deletedAt;
  final String? voidReason;
  final List<SaleItem> items;
  final List<Payment> payments;
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'] as String,
    branchId: j['branchId'] as String,
    deviceId: j['deviceId'] as String,
    shiftId: j['shiftId'] as String,
    receiptNumber: j['receiptNumber'] as String,
    status: j['status'] as String,
    currency: j['currency'] as String,
    subtotalMinor: j['subtotalMinor'] as int,
    discountMinor: j['discountMinor'] as int,
    taxMinor: j['taxMinor'] as int,
    totalMinor: j['totalMinor'] as int,
    paidMinor: j['paidMinor'] as int,
    changeMinor: j['changeMinor'] as int,
    itemCount: j['itemCount'] as int,
    soldAt: utc(j['soldAt'] as String),
    voidedAt: j['voidedAt'] == null ? null : utc(j['voidedAt'] as String),
    voidReason: j['voidReason'] as String?,
    items: (j['items'] as List)
        .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    payments: const [],
    createdAt: utc(j['createdAt'] as String),
    updatedAt: utc(j['updatedAt'] as String),
    version: j['version'] as int,
    deletedAt: j['deletedAt'] == null ? null : utc(j['deletedAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'deviceId': deviceId,
    'shiftId': shiftId,
    'receiptNumber': receiptNumber,
    'status': status,
    'currency': currency,
    'subtotalMinor': subtotalMinor,
    'discountMinor': discountMinor,
    'taxMinor': taxMinor,
    'totalMinor': totalMinor,
    'paidMinor': paidMinor,
    'changeMinor': changeMinor,
    'itemCount': itemCount,
    'soldAt': iso(soldAt),
    'voidedAt': voidedAt == null ? null : iso(voidedAt!),
    'voidReason': voidReason,
    'items': items.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
    'createdAt': iso(createdAt),
    'updatedAt': iso(updatedAt),
    'version': version,
    'deletedAt': deletedAt == null ? null : iso(deletedAt!),
  };
}

@immutable
class Shift {
  const Shift({
    required this.id,
    required this.branchId,
    required this.deviceId,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingCashMinor,
    this.closingCashMinor,
    this.expectedCashMinor,
    this.cashDifferenceMinor,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
  final String id, branchId, deviceId, status, currency;
  final DateTime openedAt, createdAt, updatedAt;
  final DateTime? closedAt;
  final int openingCashMinor, version;
  final int? closingCashMinor, expectedCashMinor, cashDifferenceMinor;
}

@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.branchId,
    required this.deviceId,
    required this.productId,
    required this.type,
    required this.sourceUnitId,
    required this.sourceUnitCodeSnapshot,
    required this.sourceUnitNameSnapshot,
    required this.sourceQuantityMinor,
    required this.sourceQuantityScale,
    required this.conversionNumeratorSnapshot,
    required this.conversionDenominatorSnapshot,
    required this.baseQuantityMinor,
    required this.baseQuantityScale,
    required this.referenceType,
    required this.referenceId,
    required this.occurredAt,
    this.note,
    required this.createdAt,
    required this.version,
  });
  final String id,
      branchId,
      deviceId,
      productId,
      type,
      sourceUnitId,
      sourceUnitCodeSnapshot,
      sourceUnitNameSnapshot,
      referenceType,
      referenceId;
  final int sourceQuantityMinor,
      sourceQuantityScale,
      conversionNumeratorSnapshot,
      conversionDenominatorSnapshot,
      baseQuantityMinor,
      baseQuantityScale,
      version;
  final DateTime occurredAt, createdAt;
  final String? note;
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'deviceId': deviceId,
    'productId': productId,
    'type': type,
    'sourceUnitId': sourceUnitId,
    'sourceUnitCodeSnapshot': sourceUnitCodeSnapshot,
    'sourceUnitNameSnapshot': sourceUnitNameSnapshot,
    'sourceQuantityMinor': sourceQuantityMinor,
    'sourceQuantityScale': sourceQuantityScale,
    'conversionNumeratorSnapshot': conversionNumeratorSnapshot,
    'conversionDenominatorSnapshot': conversionDenominatorSnapshot,
    'baseQuantityMinor': baseQuantityMinor,
    'baseQuantityScale': baseQuantityScale,
    'referenceType': referenceType,
    'referenceId': referenceId,
    'occurredAt': iso(occurredAt),
    'note': note,
    'createdAt': iso(createdAt),
    'version': version,
  };
}

@immutable
class SyncEvent {
  const SyncEvent({
    required this.id,
    required this.branchId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.entityVersion,
    required this.payload,
    required this.occurredAt,
    required this.createdAt,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    this.lastError,
    this.syncedAt,
  });
  final String id, branchId, deviceId, entityType, entityId, operation, status;
  final int entityVersion, retryCount;
  final Map<String, dynamic> payload;
  final DateTime occurredAt, createdAt;
  final DateTime? lastAttemptAt, syncedAt;
  final String? lastError;
  factory SyncEvent.fromJson(Map<String, dynamic> j) => SyncEvent(
    id: j['id'] as String,
    branchId: j['branchId'] as String,
    deviceId: j['deviceId'] as String,
    entityType: j['entityType'] as String,
    entityId: j['entityId'] as String,
    operation: j['operation'] as String,
    entityVersion: j['entityVersion'] as int,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    occurredAt: utc(j['occurredAt'] as String),
    createdAt: utc(j['createdAt'] as String),
    status: j['status'] as String,
    retryCount: j['retryCount'] as int,
    lastAttemptAt: j['lastAttemptAt'] == null
        ? null
        : utc(j['lastAttemptAt'] as String),
    lastError: j['lastError'] as String?,
    syncedAt: j['syncedAt'] == null ? null : utc(j['syncedAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'branchId': branchId,
    'deviceId': deviceId,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation,
    'entityVersion': entityVersion,
    'payload': payload,
    'occurredAt': iso(occurredAt),
    'createdAt': iso(createdAt),
    'status': status,
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt == null ? null : iso(lastAttemptAt!),
    'lastError': lastError,
    'syncedAt': syncedAt == null ? null : iso(syncedAt!),
  };
}

@immutable
class SyncPushRequest {
  const SyncPushRequest({
    this.protocolVersion = 1,
    required this.branchId,
    required this.deviceId,
    required this.events,
  });
  final int protocolVersion;
  final String branchId, deviceId;
  final List<SyncEvent> events;
  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'branchId': branchId,
    'deviceId': deviceId,
    'events': events
        .map(
          (e) => {
            'id': e.id,
            'entityType': e.entityType,
            'entityId': e.entityId,
            'operation': e.operation,
            'entityVersion': e.entityVersion,
            'occurredAt': iso(e.occurredAt),
            'payload': e.payload,
          },
        )
        .toList(),
  };
  String encode() => jsonEncode(toJson());
}

@immutable
class SyncPushResponse {
  const SyncPushResponse({
    required this.protocolVersion,
    required this.accepted,
    required this.rejected,
    required this.serverTime,
  });
  final int protocolVersion;
  final List<Map<String, dynamic>> accepted, rejected;
  final DateTime serverTime;
  factory SyncPushResponse.fromJson(Map<String, dynamic> j) => SyncPushResponse(
    protocolVersion: j['protocolVersion'] as int,
    accepted: (j['accepted'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    rejected: (j['rejected'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    serverTime: utc(j['serverTime'] as String),
  );
}
