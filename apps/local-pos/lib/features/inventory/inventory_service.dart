import 'dart:convert';

import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/core/domain/unit_conversion.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const inventoryAdjustmentTypes = {'adjustment_in', 'adjustment_out', 'waste'};
const inventoryReasonCodes = {
  'physical_count',
  'damaged',
  'expired',
  'lost',
  'found',
  'data_correction',
  'internal_use',
  'other',
};

class InventoryException implements Exception {
  const InventoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum InventoryFailurePoint { outbox }

typedef InventoryFailureHook = void Function(InventoryFailurePoint point);

enum StockStatus { normal, low, outOfStock, negative }

String stockStatusLabel(StockStatus status) => switch (status) {
  StockStatus.outOfStock => 'out_of_stock',
  _ => status.name,
};

class StockBalance {
  const StockBalance({
    required this.branchId,
    required this.productId,
    required this.baseQuantityMinor,
    required this.baseQuantityScale,
    required this.calculatedAt,
  });
  final String branchId, productId;
  final int baseQuantityMinor, baseQuantityScale;
  final DateTime calculatedAt;
}

class StockListItem {
  const StockListItem(this.product, this.balance, this.status, this.display);
  final Product product;
  final StockBalance balance;
  final StockStatus status;
  final StockDisplay display;
}

class StockDisplayPart {
  const StockDisplayPart(this.quantityMinor, this.quantityScale, this.unitName);
  final int quantityMinor, quantityScale;
  final String unitName;
}

class StockDisplay {
  const StockDisplay(this.negative, this.parts);
  final bool negative;
  final List<StockDisplayPart> parts;
  String get label {
    final value = parts
        .map(
          (p) =>
              '${_formatQuantity(p.quantityMinor, p.quantityScale)} ${p.unitName}',
        )
        .join(' + ');
    return negative ? '-$value' : value;
  }
}

class StockBalanceService {
  StockBalanceService(this.db);
  final AppDatabase db;

  Future<StockBalance> getProductBalance(
    String branchId,
    String productId,
  ) async {
    final product =
        await (db.select(db.products)..where(
              (p) => p.id.equals(productId) & p.branchId.equals(branchId),
            ))
            .getSingleOrNull();
    if (product == null) throw const InventoryException('Product not found');
    final rows = await _aggregates(branchId, [productId]);
    return _balance(product, rows[productId]);
  }

  Future<Map<String, StockBalance>> getBalancesForProducts(
    String branchId,
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};
    final products = await (db.select(
      db.products,
    )..where((p) => p.branchId.equals(branchId) & p.id.isIn(productIds))).get();
    final rows = await _aggregates(branchId, productIds);
    return {
      for (final product in products)
        product.id: _balance(product, rows[product.id]),
    };
  }

  Future<List<StockListItem>> listBranchBalances(
    String branchId, {
    String search = '',
    int limit = 100,
  }) async {
    final query = db.select(db.products)
      ..where(
        (p) =>
            p.branchId.equals(branchId) &
            p.trackStock.equals(true) &
            p.active.equals(true) &
            p.deletedAt.isNull(),
      )
      ..orderBy([(p) => OrderingTerm.asc(p.name)])
      ..limit(limit.clamp(1, 100));
    if (search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query.where((p) => p.name.like(pattern) | p.sku.like(pattern));
    }
    final products = await query.get();
    final balances = await getBalancesForProducts(
      branchId,
      products.map((p) => p.id).toList(),
    );
    final productIds = products.map((p) => p.id).toList();
    final units = productIds.isEmpty
        ? <ProductUnit>[]
        : await (db.select(db.productUnits)..where(
                (unit) =>
                    unit.productId.isIn(productIds) &
                    unit.active.equals(true) &
                    unit.deletedAt.isNull(),
              ))
              .get();
    final unitsByProduct = <String, List<ProductUnit>>{};
    for (final unit in units) {
      unitsByProduct.putIfAbsent(unit.productId, () => []).add(unit);
    }
    return [
      for (final product in products)
        StockListItem(
          product,
          balances[product.id]!,
          stockStatus(product, balances[product.id]!.baseQuantityMinor),
          StockDisplayConversionService().convert(
            balances[product.id]!.baseQuantityMinor,
            product,
            unitsByProduct[product.id] ?? [],
          ),
        ),
    ];
  }

  StockStatus stockStatus(Product product, int balance) {
    if (balance < 0) return StockStatus.negative;
    if (balance == 0) return StockStatus.outOfStock;
    final threshold = product.lowStockThresholdMinor;
    if (threshold != null &&
        product.lowStockThresholdScale == product.baseQuantityScale &&
        balance <= threshold) {
      return StockStatus.low;
    }
    return StockStatus.normal;
  }

  StockBalance _balance(Product product, _Aggregate? aggregate) {
    if (aggregate != null && aggregate.scales.length != 1) {
      throw const InventoryException('Canonical scale mismatch');
    }
    if (aggregate != null &&
        aggregate.scales.single != product.baseQuantityScale) {
      throw const InventoryException('Canonical scale mismatch');
    }
    return StockBalance(
      branchId: product.branchId,
      productId: product.id,
      baseQuantityMinor: aggregate?.total ?? 0,
      baseQuantityScale: product.baseQuantityScale,
      calculatedAt: DateTime.now().toUtc(),
    );
  }

  Future<Map<String, _Aggregate>> _aggregates(
    String branchId,
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};
    final placeholders = List.filled(productIds.length, '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT product_id, base_quantity_scale, SUM(base_quantity_minor) AS total '
          'FROM stock_movements WHERE branch_id = ? AND product_id IN ($placeholders) '
          'GROUP BY product_id, base_quantity_scale',
          variables: [Variable(branchId), ...productIds.map(Variable.new)],
          readsFrom: {db.stockMovements},
        )
        .get();
    final result = <String, _Aggregate>{};
    for (final row in rows) {
      final productId = row.read<String>('product_id');
      final scale = row.read<int>('base_quantity_scale');
      final total = row.read<int>('total');
      result.update(
        productId,
        (value) => value..add(scale, total),
        ifAbsent: () => _Aggregate(scale, total),
      );
    }
    return result;
  }
}

class _Aggregate {
  _Aggregate(int scale, this.total) : scales = {scale};
  final Set<int> scales;
  int total;
  void add(int scale, int amount) {
    scales.add(scale);
    total += amount;
  }
}

class StockDisplayConversionService {
  StockDisplay convert(
    int balanceMinor,
    Product product,
    List<ProductUnit> units,
  ) {
    final active = units
        .where(
          (u) => u.active && u.deletedAt == null && u.productId == product.id,
        )
        .toList();
    final base = active.where((u) => u.isBaseUnit).firstOrNull;
    if (base == null) {
      throw const InventoryException('Product unit unavailable');
    }
    final negative = balanceMinor < 0;
    var remaining = balanceMinor.abs();
    final packages = <(ProductUnit, int)>[];
    for (final unit in active.where((u) => !u.isBaseUnit)) {
      final dividend = unit.conversionNumerator * product.baseQuantityScale;
      if (dividend % unit.conversionDenominator == 0) {
        packages.add((unit, dividend ~/ unit.conversionDenominator));
      }
    }
    packages.sort((a, b) => b.$2.compareTo(a.$2));
    final parts = <StockDisplayPart>[];
    if (packages.isNotEmpty && packages.first.$2 > 0) {
      final count = remaining ~/ packages.first.$2;
      if (count > 0) {
        parts.add(StockDisplayPart(count, 1, packages.first.$1.name));
        remaining %= packages.first.$2;
      }
    }
    if (remaining > 0 || parts.isEmpty) {
      parts.add(
        StockDisplayPart(remaining, product.baseQuantityScale, base.name),
      );
    }
    return StockDisplay(negative, parts);
  }
}

String _formatQuantity(int minor, int scale) {
  if (scale == 1) return minor.toString();
  final whole = minor ~/ scale;
  var fraction = (minor % scale).toString().padLeft(
    scale.toString().length - 1,
    '0',
  );
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}

class StockMovementRepository {
  StockMovementRepository(this.db);
  final AppDatabase db;
  Future<void> insertMovement(StockMovementsCompanion movement) =>
      db.into(db.stockMovements).insert(movement);
  Future<StockMovement?> getMovementById(String id) => (db.select(
    db.stockMovements,
  )..where((m) => m.id.equals(id))).getSingleOrNull();
  Future<List<StockMovement>> listMovementsForProduct(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) => _list((m) => m.productId.equals(productId), limit, offset);
  Future<List<StockMovement>> listMovementsForBranch(
    String branchId, {
    int limit = 50,
    int offset = 0,
  }) => _list((m) => m.branchId.equals(branchId), limit, offset);
  Future<List<StockMovement>> listMovementsByType(
    String branchId,
    String type, {
    int limit = 50,
    int offset = 0,
  }) => _list(
    (m) => m.branchId.equals(branchId) & m.type.equals(type),
    limit,
    offset,
  );
  Future<List<StockMovement>> listMovementsByDateRange(
    String branchId,
    DateTime from,
    DateTime to, {
    int limit = 50,
    int offset = 0,
  }) => _list(
    (m) =>
        m.branchId.equals(branchId) &
        m.occurredAt.isBiggerOrEqualValue(from) &
        m.occurredAt.isSmallerThanValue(to),
    limit,
    offset,
  );
  Future<List<StockMovement>> listMovementsByReference(
    String type,
    String id, {
    int limit = 50,
    int offset = 0,
  }) => _list(
    (m) => m.referenceType.equals(type) & m.referenceId.equals(id),
    limit,
    offset,
  );
  Future<List<StockMovement>> _list(
    Expression<bool> Function(StockMovements m) where,
    int limit,
    int offset,
  ) =>
      (db.select(db.stockMovements)
            ..where(where)
            ..orderBy([
              (m) => OrderingTerm.desc(m.occurredAt),
              (m) => OrderingTerm.desc(m.createdAt),
            ])
            ..limit(limit.clamp(1, 100), offset: offset < 0 ? 0 : offset))
          .get();

  Future<List<InventoryLedgerEntry>> listLedger(
    String branchId, {
    String? productId,
    String? type,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final filters = <String>['sm.branch_id = ?'];
    final variables = <Variable>[Variable(branchId)];
    if (productId != null) {
      filters.add('sm.product_id = ?');
      variables.add(Variable(productId));
    }
    if (type != null) {
      filters.add('sm.type = ?');
      variables.add(Variable(type));
    }
    if (from != null) {
      filters.add('sm.occurred_at >= ?');
      variables.add(Variable(from.millisecondsSinceEpoch));
    }
    if (to != null) {
      filters.add('sm.occurred_at < ?');
      variables.add(Variable(to.millisecondsSinceEpoch));
    }
    variables.add(Variable(limit.clamp(1, 100)));
    variables.add(Variable(offset < 0 ? 0 : offset));
    final rows = await db
        .customSelect(
          'SELECT sm.id, sm.product_id, p.name AS product_name, sm.type, '
          'sm.source_unit_name_snapshot, sm.source_quantity_minor, '
          'sm.source_quantity_scale, sm.base_quantity_minor, sm.base_quantity_scale, '
          'sm.reason_code, sm.reference_type, sm.reference_id, sm.occurred_at, sm.note, '
          'SUM(sm.base_quantity_minor) OVER (PARTITION BY sm.branch_id, sm.product_id '
          'ORDER BY sm.occurred_at, sm.created_at, sm.id '
          'ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance_after '
          'FROM stock_movements sm LEFT JOIN products p ON p.id = sm.product_id '
          'WHERE ${filters.join(' AND ')} '
          'ORDER BY sm.occurred_at DESC, sm.created_at DESC, sm.id DESC LIMIT ? OFFSET ?',
          variables: variables,
          readsFrom: {db.stockMovements, db.products},
        )
        .get();
    return [
      for (final row in rows)
        InventoryLedgerEntry(
          movementId: row.read('id'),
          productId: row.read('product_id'),
          productName: row.readNullable('product_name') ?? 'Unknown product',
          movementType: row.read('type'),
          sourceUnitName: row.read('source_unit_name_snapshot'),
          sourceQuantityMinor: row.read('source_quantity_minor'),
          sourceQuantityScale: row.read('source_quantity_scale'),
          baseQuantityMinor: row.read('base_quantity_minor'),
          baseQuantityScale: row.read('base_quantity_scale'),
          balanceAfterMovement: row.read('balance_after'),
          reasonCode: row.readNullable('reason_code'),
          referenceType: row.read('reference_type'),
          referenceId: row.read('reference_id'),
          occurredAt: DateTime.fromMillisecondsSinceEpoch(
            row.read('occurred_at'),
            isUtc: true,
          ),
          note: row.readNullable('note'),
        ),
    ];
  }
}

class InventoryLedgerEntry {
  const InventoryLedgerEntry({
    required this.movementId,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.sourceUnitName,
    required this.sourceQuantityMinor,
    required this.sourceQuantityScale,
    required this.baseQuantityMinor,
    required this.baseQuantityScale,
    required this.balanceAfterMovement,
    this.reasonCode,
    required this.referenceType,
    required this.referenceId,
    required this.occurredAt,
    this.note,
  });
  final String movementId,
      productId,
      productName,
      movementType,
      sourceUnitName,
      referenceType,
      referenceId;
  final int sourceQuantityMinor,
      sourceQuantityScale,
      baseQuantityMinor,
      baseQuantityScale,
      balanceAfterMovement;
  final String? reasonCode, note;
  final DateTime occurredAt;
}

class InventoryMovementService {
  InventoryMovementService(this.db, {this.failureHook});
  final AppDatabase db;
  final InventoryFailureHook? failureHook;

  Future<StockMovement> receive({
    required String branchId,
    required String deviceId,
    required String productId,
    required String productUnitId,
    required int quantityMinor,
    required int quantityScale,
    DateTime? occurredAt,
    String? note,
  }) => _create(
    branchId: branchId,
    deviceId: deviceId,
    productId: productId,
    productUnitId: productUnitId,
    type: 'purchase',
    quantityMinor: quantityMinor,
    quantityScale: quantityScale,
    requirePurchase: true,
    reasonCode: null,
    note: note,
    occurredAt: occurredAt,
  );

  Future<StockMovement> opening({
    required String branchId,
    required String deviceId,
    required String productId,
    required String productUnitId,
    required int quantityMinor,
    required int quantityScale,
    required String note,
    DateTime? occurredAt,
  }) {
    if (note.trim().isEmpty) throw const InventoryException('Reason required');
    return _create(
      branchId: branchId,
      deviceId: deviceId,
      productId: productId,
      productUnitId: productUnitId,
      type: 'opening',
      quantityMinor: quantityMinor,
      quantityScale: quantityScale,
      requirePurchase: true,
      reasonCode: 'data_correction',
      note: note,
      occurredAt: occurredAt,
      openingOnly: true,
    );
  }

  Future<StockMovement> adjust({
    required String branchId,
    required String deviceId,
    required String productId,
    required String productUnitId,
    required String type,
    required int quantityMinor,
    required int quantityScale,
    required String reasonCode,
    String? note,
    DateTime? occurredAt,
  }) {
    if (!inventoryAdjustmentTypes.contains(type)) {
      throw const InventoryException('Invalid movement type');
    }
    if (!inventoryReasonCodes.contains(reasonCode) ||
        (reasonCode == 'other' && (note == null || note.trim().isEmpty))) {
      throw const InventoryException('Reason required');
    }
    return _create(
      branchId: branchId,
      deviceId: deviceId,
      productId: productId,
      productUnitId: productUnitId,
      type: type,
      quantityMinor: quantityMinor,
      quantityScale: quantityScale,
      requirePurchase: false,
      reasonCode: reasonCode,
      note: note,
      occurredAt: occurredAt,
    );
  }

  Future<StockMovement> _create({
    required String branchId,
    required String deviceId,
    required String productId,
    required String productUnitId,
    required String type,
    required int quantityMinor,
    required int quantityScale,
    required bool requirePurchase,
    required String? reasonCode,
    required String? note,
    required DateTime? occurredAt,
    bool openingOnly = false,
  }) async {
    if (quantityMinor <= 0 || quantityScale <= 0) {
      throw const InventoryException('Invalid quantity');
    }
    try {
      return await db.transaction(() async {
        final product =
            await (db.select(db.products)..where(
                  (p) => p.id.equals(productId) & p.branchId.equals(branchId),
                ))
                .getSingleOrNull();
        if (product == null) {
          throw const InventoryException('Product not found');
        }
        if (!product.active || product.deletedAt != null) {
          throw const InventoryException('Product inactive');
        }
        if (!product.trackStock) {
          throw const InventoryException('Product does not track stock');
        }
        final unit = await (db.select(
          db.productUnits,
        )..where((u) => u.id.equals(productUnitId))).getSingleOrNull();
        if (unit == null || !unit.active || unit.deletedAt != null) {
          throw const InventoryException('Product unit unavailable');
        }
        if (unit.productId != productId) {
          throw const InventoryException('Unit belongs to another product');
        }
        if (unit.branchId != branchId) {
          throw const InventoryException('Unit belongs to another branch');
        }
        if (requirePurchase && !unit.allowPurchase) {
          throw const InventoryException('Product unit unavailable');
        }
        if (openingOnly &&
            await (db.select(db.stockMovements)
                      ..where(
                        (m) =>
                            m.branchId.equals(branchId) &
                            m.productId.equals(productId),
                      )
                      ..limit(1))
                    .getSingleOrNull() !=
                null) {
          throw const InventoryException('Opening stock already exists');
        }
        int base;
        try {
          base = UnitConversion.toBaseMinor(
            quantityMinor: quantityMinor,
            quantityScale: quantityScale,
            conversionNumerator: unit.conversionNumerator,
            conversionDenominator: unit.conversionDenominator,
            baseQuantityScale: product.baseQuantityScale,
          );
        } catch (_) {
          throw const InventoryException('Non-exact conversion');
        }
        if ({'adjustment_out', 'waste'}.contains(type)) {
          base = -base;
        }
        if (base == 0) {
          throw const InventoryException('Invalid movement direction');
        }
        final now = (occurredAt ?? DateTime.now()).toUtc();
        final id = const Uuid().v7();
        final referenceType = switch (type) {
          'purchase' => 'manual_receiving',
          'opening' => 'opening_stock',
          _ => 'manual_adjustment',
        };
        await db
            .into(db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                id: id,
                branchId: branchId,
                deviceId: deviceId,
                productId: productId,
                type: type,
                sourceUnitId: unit.id,
                sourceUnitCodeSnapshot: unit.code,
                sourceUnitNameSnapshot: unit.name,
                sourceQuantityMinor: quantityMinor,
                sourceQuantityScale: quantityScale,
                conversionNumeratorSnapshot: unit.conversionNumerator,
                conversionDenominatorSnapshot: unit.conversionDenominator,
                baseQuantityMinor: base,
                baseQuantityScale: product.baseQuantityScale,
                referenceType: referenceType,
                referenceId: id,
                occurredAt: now,
                note: Value(note),
                reasonCode: Value(reasonCode),
                createdAt: now,
                version: 1,
              ),
            );
        final movement = await (db.select(
          db.stockMovements,
        )..where((m) => m.id.equals(id))).getSingle();
        failureHook?.call(InventoryFailurePoint.outbox);
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: const Uuid().v7(),
                branchId: branchId,
                deviceId: deviceId,
                entityType: 'stock_movement',
                entityId: id,
                operation: 'append',
                entityVersion: 1,
                payloadJson: jsonEncode(_movementJson(movement)),
                occurredAt: now,
                createdAt: now,
              ),
            );
        return movement;
      });
    } on InventoryException {
      rethrow;
    } catch (_) {
      throw const InventoryException('Database transaction failure');
    }
  }
}

Map<String, dynamic> _movementJson(StockMovement m) => {
  'id': m.id,
  'branchId': m.branchId,
  'deviceId': m.deviceId,
  'productId': m.productId,
  'type': m.type,
  'sourceUnitId': m.sourceUnitId,
  'sourceUnitCodeSnapshot': m.sourceUnitCodeSnapshot,
  'sourceUnitNameSnapshot': m.sourceUnitNameSnapshot,
  'sourceQuantityMinor': m.sourceQuantityMinor,
  'sourceQuantityScale': m.sourceQuantityScale,
  'conversionNumeratorSnapshot': m.conversionNumeratorSnapshot,
  'conversionDenominatorSnapshot': m.conversionDenominatorSnapshot,
  'baseQuantityMinor': m.baseQuantityMinor,
  'baseQuantityScale': m.baseQuantityScale,
  'referenceType': m.referenceType,
  'referenceId': m.referenceId,
  'reasonCode': m.reasonCode,
  'occurredAt': m.occurredAt.toIso8601String(),
  'note': m.note,
  'createdAt': m.createdAt.toIso8601String(),
  'version': m.version,
};

final stockBalanceServiceProvider = Provider(
  (ref) => StockBalanceService(ref.watch(databaseProvider)),
);
final stockMovementRepositoryProvider = Provider(
  (ref) => StockMovementRepository(ref.watch(databaseProvider)),
);
final stockDisplayConversionServiceProvider = Provider(
  (ref) => StockDisplayConversionService(),
);
final inventoryMovementServiceProvider = Provider(
  (ref) => InventoryMovementService(ref.watch(databaseProvider)),
);
final receiveStockServiceProvider = Provider(
  (ref) => ref.watch(inventoryMovementServiceProvider),
);
final stockAdjustmentServiceProvider = Provider(
  (ref) => ref.watch(inventoryMovementServiceProvider),
);
final stockListProvider = FutureProvider.family<List<StockListItem>, String>(
  (ref, branchId) =>
      ref.watch(stockBalanceServiceProvider).listBranchBalances(branchId),
);
final productStockBalanceProvider =
    FutureProvider.family<StockBalance, (String, String)>(
      (ref, key) => ref
          .watch(stockBalanceServiceProvider)
          .getProductBalance(key.$1, key.$2),
    );
final stockLedgerProvider =
    FutureProvider.family<List<InventoryLedgerEntry>, (String, String?)>(
      (ref, key) => ref
          .watch(stockMovementRepositoryProvider)
          .listLedger(key.$1, productId: key.$2),
    );
