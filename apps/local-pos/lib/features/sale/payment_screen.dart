import 'package:auice_pos/features/sale/cart.dart';
import 'package:auice_pos/features/sale/money_parser.dart';
import 'package:auice_pos/features/sale/money_formatter.dart';
import 'package:auice_pos/features/sale/sale_completion_service.dart';
import 'package:auice_pos/features/sale/sale_repository.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final cash = TextEditingController();
  String? error;
  bool saving = false;
  @override
  void dispose() {
    cash.dispose();
    super.dispose();
  }

  int? get parsed {
    try {
      return MoneyParser.parseMinor(cash.text);
    } catch (_) {
      return null;
    }
  }

  Future<void> confirm() async {
    setState(() {
      error = null;
      saving = true;
    });
    try {
      final paid = MoneyParser.parseMinor(cash.text);
      final receipt = await ref
          .read(checkoutControllerProvider)
          .completeCash(paid);
      ref.invalidate(recentSalesProvider);
      ref.invalidate(shiftSummaryProvider(receipt.sale.shiftId));
      if (mounted) context.go('/receipt/${receipt.sale.id}');
    } on SaleException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final received = parsed;
    final change = received == null ? null : received - cart.totalMinor;
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Payment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Total due: ${money(cart.totalMinor)} THB',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          TextField(
            controller: cash,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cash received'),
            onChanged: (_) => setState(() {}),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in [10000, 50000, 100000])
                ActionChip(
                  label: Text(money(amount)),
                  onPressed: () {
                    cash.text = money(amount);
                    setState(() {});
                  },
                ),
            ],
          ),
          if (change != null)
            Text('Change: ${money(change < 0 ? 0 : change)} THB'),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: saving ? null : confirm,
            child: const Text('Confirm payment'),
          ),
        ],
      ),
    );
  }
}
