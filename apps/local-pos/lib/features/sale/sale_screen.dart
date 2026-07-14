import 'package:auice_pos/core/catalog/catalog_repository.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/sale/cart.dart';
import 'package:auice_pos/features/sale/money_formatter.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:auice_pos/features/startup/cloud_connection_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key});
  @override
  ConsumerState<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends ConsumerState<SaleScreen> {
  final search = TextEditingController();
  List<CatalogSaleOption> results = [];
  String? error;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> runSearch() async {
    final db = ref.read(databaseProvider);
    final branch = await db.select(db.branches).getSingleOrNull();
    if (branch == null) {
      setState(() => error = 'Catalog is not configured');
      return;
    }
    final found = await ref
        .read(catalogRepositoryProvider)
        .searchSaleOptions(branch.id, search.text.trim());
    if (mounted) {
      setState(() {
        results = found;
        error = found.isEmpty ? 'No products found' : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(openShiftProvider);
    final cart = ref.watch(cartProvider);
    final cloud = ref.watch(cloudConnectionProvider).status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale'),
        actions: [
          IconButton(
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Sale history',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mode: ${cloud == CloudConnectionStatus.online ? 'Online' : 'Offline ready'}',
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    labelText: 'Product name, SKU or barcode',
                  ),
                  onSubmitted: (_) => runSearch(),
                ),
              ),
              IconButton(onPressed: runSearch, icon: const Icon(Icons.search)),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final option in results)
            ListTile(
              title: Text(option.product.name),
              subtitle: Text(
                '${option.unit.name} • ${money(option.price!.priceMinor)} THB',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => ref
                    .read(cartProvider.notifier)
                    .add(option.product, option.unit, option.price!),
              ),
            ),
          const Divider(),
          Text('Cart', style: Theme.of(context).textTheme.titleLarge),
          if (cart.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cart is empty'),
            ),
          for (final item in cart.items)
            ListTile(
              title: Text(item.product.name),
              subtitle: Text(
                '${item.unit.name} • ${item.quantityMinor}/${item.quantityScale} × ${money(item.price.priceMinor)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${money(item.totalMinor)} THB'),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        ref.read(cartProvider.notifier).remove(item.unit.id),
                  ),
                ],
              ),
              onTap: () async {
                final controller = TextEditingController(
                  text: item.quantityMinor.toString(),
                );
                final value = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Quantity — ${item.unit.name}'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                );
                final quantity = int.tryParse(value ?? '');
                if (quantity != null) {
                  ref
                      .read(cartProvider.notifier)
                      .setQuantity(item.unit.id, quantity);
                }
              },
            ),
          const Divider(),
          Text(
            'Total: ${money(cart.totalMinor)} THB',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          FilledButton(
            onPressed: cart.items.isEmpty
                ? null
                : () => context.push('/payment'),
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }
}
