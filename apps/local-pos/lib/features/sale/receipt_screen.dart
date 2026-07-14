import 'package:auice_pos/features/sale/sale_repository.dart';
import 'package:auice_pos/features/sale/sale_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({required this.saleId, super.key});
  final String saleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptProvider(saleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: receipt.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load receipt')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Receipt not found'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                data.branchName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(data.sale.receiptNumber, key: const Key('receipt-number')),
              Text(data.sale.soldAt.toLocal().toString()),
              Text('Device: ${data.sale.deviceId}'),
              for (final item in data.items)
                ListTile(
                  title: Text(item.productNameSnapshot),
                  subtitle: Text(
                    '${item.unitNameSnapshot} • ${item.quantityMinor}/${item.quantityScale} × ${money(item.unitPriceMinor)}',
                  ),
                  trailing: Text(money(item.totalMinor)),
                ),
              Text('Total: ${money(data.sale.totalMinor)} THB'),
              Text('Paid: ${money(data.sale.paidMinor)} THB'),
              Text('Change: ${money(data.sale.changeMinor)} THB'),
              const Text('Sync: Pending'),
              FilledButton(
                onPressed: () => context.go('/sale'),
                child: const Text('New sale'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SaleHistoryScreen extends ConsumerWidget {
  const SaleHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(recentSalesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sale History')),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load sale history')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No completed sales'))
            : ListView(
                children: [
                  for (final sale in rows)
                    ListTile(
                      title: Text(sale.receiptNumber),
                      subtitle: Text('${sale.soldAt.toLocal()} • Sync pending'),
                      trailing: Text('${money(sale.totalMinor)} THB'),
                      onTap: () => context.push('/receipt/${sale.id}'),
                    ),
                ],
              ),
      ),
    );
  }
}
