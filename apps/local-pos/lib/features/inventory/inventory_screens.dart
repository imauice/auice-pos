import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/core/domain/unit_conversion.dart';
import 'package:auice_pos/features/inventory/inventory_service.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});
  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shiftConfigurationProvider);
    final ready = config.valueOrNull;
    if (ready == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!ready.isReady) {
      return Scaffold(body: Center(child: Text(ready.message)));
    }
    final branchId = ready.branch!.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            onPressed: () => context.push('/inventory/ledger/$branchId'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: ref
          .watch(stockListProvider(branchId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (items) {
              final needle = search.text.trim().toLowerCase();
              final filtered = needle.isEmpty
                  ? items
                  : items
                        .where(
                          (item) =>
                              item.product.name.toLowerCase().contains(
                                needle,
                              ) ||
                              (item.product.sku?.toLowerCase().contains(
                                    needle,
                                  ) ??
                                  false),
                        )
                        .toList();
              return items.isEmpty
                  ? const Center(child: Text('No stock-tracked products'))
                  : ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: search,
                            decoration: const InputDecoration(
                              labelText: 'Search',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        for (final item in filtered)
                          ListTile(
                            title: Text(item.product.name),
                            subtitle: Text(
                              '${item.product.sku ?? '-'} • ${item.balance.baseQuantityMinor}/${item.balance.baseQuantityScale} • ${item.display.label} • ${stockStatusLabel(item.status)}',
                            ),
                            textColor: item.status == StockStatus.negative
                                ? Theme.of(context).colorScheme.error
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/inventory/product/$branchId/${item.product.id}',
                            ),
                          ),
                      ],
                    );
            },
          ),
    );
  }
}

class ProductStockDetailScreen extends ConsumerWidget {
  const ProductStockDetailScreen({
    required this.branchId,
    required this.productId,
    super.key,
  });
  final String branchId, productId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Product Stock')),
    body: FutureBuilder(
      future: Future.wait([
        (ref.read(databaseProvider).select(ref.read(databaseProvider).products)
              ..where((p) => p.id.equals(productId)))
            .getSingle(),
        (ref
                .read(databaseProvider)
                .select(ref.read(databaseProvider).productUnits)
              ..where(
                (u) => u.productId.equals(productId) & u.deletedAt.isNull(),
              ))
            .get(),
      ]),
      builder: (context, snapshot) {
        final balance = ref.watch(
          productStockBalanceProvider((branchId, productId)),
        );
        if (!snapshot.hasData || balance.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final product = snapshot.data![0] as Product;
        final units = snapshot.data![1] as List<ProductUnit>;
        final stock = balance.value!;
        final display = ref
            .read(stockDisplayConversionServiceProvider)
            .convert(stock.baseQuantityMinor, product, units);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Base balance: ${stock.baseQuantityMinor}/${stock.baseQuantityScale}',
            ),
            Text('Display: ${display.label}'),
            Text(
              'Low threshold: ${product.lowStockThresholdMinor?.toString() ?? 'Not set'}',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => context.push(
                    '/inventory/move/$branchId/$productId/purchase',
                  ),
                  child: const Text('Receive'),
                ),
                FilledButton.tonal(
                  onPressed: () => context.push(
                    '/inventory/move/$branchId/$productId/adjustment_out',
                  ),
                  child: const Text('Adjust'),
                ),
                OutlinedButton(
                  onPressed: () => context.push(
                    '/inventory/ledger/$branchId?product=$productId',
                  ),
                  child: const Text('Movements'),
                ),
              ],
            ),
            const Divider(),
            const Text('Unit conversions'),
            for (final unit in units)
              Text(
                '${unit.name}: ${unit.conversionNumerator}/${unit.conversionDenominator}',
              ),
          ],
        );
      },
    ),
  );
}

class InventoryMovementScreen extends ConsumerStatefulWidget {
  const InventoryMovementScreen({
    required this.branchId,
    required this.productId,
    required this.type,
    super.key,
  });
  final String branchId, productId, type;
  @override
  ConsumerState<InventoryMovementScreen> createState() =>
      _InventoryMovementState();
}

class _InventoryMovementState extends ConsumerState<InventoryMovementScreen> {
  final quantity = TextEditingController(), note = TextEditingController();
  String? unitId, error;
  String type = 'adjustment_in', reason = 'physical_count';
  @override
  void initState() {
    super.initState();
    type = widget.type;
  }

  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  (int, int) parsed() {
    final value = quantity.text.trim();
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      throw const InventoryException('Invalid quantity');
    }
    final parts = value.split('.');
    final scale = parts.length == 1 ? 1 : _pow10(parts[1].length);
    return (int.parse(parts.join()), scale);
  }

  Future<void> save(List<ProductUnit> units) async {
    try {
      final config = await ref.read(shiftConfigurationProvider.future);
      if (!config.isReady || unitId == null) {
        throw const InventoryException('Product unit unavailable');
      }
      final q = parsed();
      final service = ref.read(inventoryMovementServiceProvider);
      if (type == 'purchase') {
        await service.receive(
          branchId: widget.branchId,
          deviceId: config.deviceId!,
          productId: widget.productId,
          productUnitId: unitId!,
          quantityMinor: q.$1,
          quantityScale: q.$2,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        );
      } else if (type == 'opening') {
        await service.opening(
          branchId: widget.branchId,
          deviceId: config.deviceId!,
          productId: widget.productId,
          productUnitId: unitId!,
          quantityMinor: q.$1,
          quantityScale: q.$2,
          note: note.text.trim(),
        );
      } else {
        await service.adjust(
          branchId: widget.branchId,
          deviceId: config.deviceId!,
          productId: widget.productId,
          productUnitId: unitId!,
          type: type,
          quantityMinor: q.$1,
          quantityScale: q.$2,
          reasonCode: reason,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        );
      }
      ref.invalidate(stockListProvider(widget.branchId));
      ref.invalidate(
        productStockBalanceProvider((widget.branchId, widget.productId)),
      );
      ref.invalidate(stockLedgerProvider((widget.branchId, widget.productId)));
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final canonicalScale = ref
        .watch(productStockBalanceProvider((widget.branchId, widget.productId)))
        .valueOrNull
        ?.baseQuantityScale;
    return Scaffold(
      appBar: AppBar(
        title: Text(type == 'purchase' ? 'Receive Stock' : 'Adjust Stock'),
      ),
      body: FutureBuilder<List<ProductUnit>>(
        future:
            (db.select(db.productUnits)..where(
                  (u) =>
                      u.productId.equals(widget.productId) &
                      u.active.equals(true),
                ))
                .get(),
        builder: (context, snapshot) {
          final units = snapshot.data ?? [];
          unitId ??= units.firstOrNull?.id;
          String preview = '';
          if (unitId != null && quantity.text.isNotEmpty) {
            try {
              final q = parsed();
              final unit = units.firstWhere((u) => u.id == unitId);
              final base = UnitConversion.toBaseMinor(
                quantityMinor: q.$1,
                quantityScale: q.$2,
                conversionNumerator: unit.conversionNumerator,
                conversionDenominator: unit.conversionDenominator,
                baseQuantityScale: canonicalScale ?? 1,
              );
              preview =
                  'Base quantity: ${{'adjustment_out', 'waste'}.contains(type) ? -base : base}';
            } catch (_) {
              preview = 'Non-exact conversion';
            }
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.type != 'purchase')
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'opening', child: Text('Opening')),
                    DropdownMenuItem(
                      value: 'adjustment_in',
                      child: Text('Adjustment In'),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment_out',
                      child: Text('Adjustment Out'),
                    ),
                    DropdownMenuItem(value: 'waste', child: Text('Waste')),
                  ],
                  onChanged: (value) => setState(() => type = value!),
                ),
              DropdownButtonFormField<String>(
                initialValue: unitId,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit.id, child: Text(unit.name)),
                ],
                onChanged: (value) => setState(() => unitId = value),
              ),
              TextField(
                key: const Key('inventory-quantity'),
                controller: quantity,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (!{'purchase', 'opening'}.contains(type))
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  items: [
                    for (final code in inventoryReasonCodes)
                      DropdownMenuItem(value: code, child: Text(code)),
                  ],
                  onChanged: (value) => setState(() => reason = value!),
                ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              Text(preview, key: const Key('inventory-preview')),
              if (error != null) Text(error!),
              FilledButton(
                onPressed: () => save(units),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StockLedgerScreen extends ConsumerStatefulWidget {
  const StockLedgerScreen({required this.branchId, this.productId, super.key});
  final String branchId;
  final String? productId;
  @override
  ConsumerState<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends ConsumerState<StockLedgerScreen> {
  String? type;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Movement Ledger')),
    body: ref
        .watch(stockLedgerProvider((widget.branchId, widget.productId)))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (rows) {
            final filtered = type == null
                ? rows
                : rows.where((row) => row.movementType == type).toList();
            return ListView(
              children: [
                DropdownButton<String?>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All types')),
                    DropdownMenuItem(
                      value: 'purchase',
                      child: Text('Purchase'),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment_in',
                      child: Text('Adjustment In'),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment_out',
                      child: Text('Adjustment Out'),
                    ),
                    DropdownMenuItem(value: 'waste', child: Text('Waste')),
                    DropdownMenuItem(value: 'sale', child: Text('Sale')),
                  ],
                  onChanged: (value) => setState(() => type = value),
                ),
                for (final movement in filtered)
                  ListTile(
                    title: Text(
                      '${movement.productName} • ${movement.movementType}: ${movement.baseQuantityMinor}',
                    ),
                    subtitle: Text(
                      '${movement.sourceQuantityMinor}/${movement.sourceQuantityScale} ${movement.sourceUnitName} • balance ${movement.balanceAfterMovement} • ${movement.occurredAt.toLocal()}',
                    ),
                    onTap: () => context.push(
                      '/inventory/movement/${movement.movementId}',
                    ),
                  ),
              ],
            );
          },
        ),
  );
}

class StockMovementDetailScreen extends ConsumerWidget {
  const StockMovementDetailScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Movement Detail')),
    body: FutureBuilder<StockMovement?>(
      future: ref.read(stockMovementRepositoryProvider).getMovementById(id),
      builder: (context, snapshot) {
        final movement = snapshot.data;
        if (movement == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Type: ${movement.type}'),
            Text('Unit snapshot: ${movement.sourceUnitNameSnapshot}'),
            Text(
              'Source: ${movement.sourceQuantityMinor}/${movement.sourceQuantityScale}',
            ),
            Text(
              'Conversion: ${movement.conversionNumeratorSnapshot}/${movement.conversionDenominatorSnapshot}',
            ),
            Text(
              'Base: ${movement.baseQuantityMinor}/${movement.baseQuantityScale}',
            ),
            Text('Reason: ${movement.reasonCode ?? '-'}'),
            Text(
              'Reference: ${movement.referenceType}/${movement.referenceId}',
            ),
            Text('Note: ${movement.note ?? '-'}'),
          ],
        );
      },
    ),
  );
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
