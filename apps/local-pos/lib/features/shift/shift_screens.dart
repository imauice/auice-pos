import 'package:auice_pos/features/sale/money_formatter.dart';
import 'package:auice_pos/features/sale/money_parser.dart';
import 'package:auice_pos/features/sale/shift_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _syncStatus(AsyncValue<bool> value) => value.when(
  data: (pending) => pending ? 'Pending' : 'Synced',
  loading: () => 'Checking',
  error: (_, _) => 'Unknown',
);

class ShiftGateScreen extends ConsumerWidget {
  const ShiftGateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(openShiftProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) =>
            const Scaffold(body: Center(child: Text('Unable to load shift'))),
        data: (shift) => shift == null
            ? const ShiftStartScreen()
            : ShiftDashboardScreen(shiftId: shift.id),
      );
}

class ShiftStartScreen extends ConsumerStatefulWidget {
  const ShiftStartScreen({super.key});
  @override
  ConsumerState<ShiftStartScreen> createState() => _ShiftStartState();
}

class _ShiftStartState extends ConsumerState<ShiftStartScreen> {
  final amount = TextEditingController(text: '0');
  String? error;
  bool saving = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> open() async {
    final config = await ref.read(shiftConfigurationProvider.future);
    if (!config.isReady) {
      setState(() => error = config.message);
      return;
    }
    try {
      setState(() {
        saving = true;
        error = null;
      });
      await ref
          .read(openShiftServiceProvider)
          .open(
            branchId: config.branch!.id,
            deviceId: config.deviceId!,
            openingCashMinor: MoneyParser.parseMinor(amount.text),
            currency: config.branch!.currency,
          );
      ref.invalidate(openShiftProvider);
      ref.invalidate(recentShiftsProvider);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shiftConfigurationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shift'),
        actions: [
          IconButton(
            onPressed: () => context.push('/shifts'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Branch: ${config.valueOrNull?.branch?.name ?? config.valueOrNull?.message ?? 'Loading'}',
            ),
            Text('Device: ${config.valueOrNull?.deviceId ?? 'Not configured'}'),
            TextField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Opening cash'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: saving ? null : open,
              child: const Text('Open shift'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShiftDashboardScreen extends ConsumerWidget {
  const ShiftDashboardScreen({required this.shiftId, super.key});
  final String shiftId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncPending = ref.watch(shiftSyncPendingProvider(shiftId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shift Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/shifts'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: ref
          .watch(shiftSummaryProvider(shiftId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Unable to load shift summary')),
            data: (s) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Opened: ${s.shift.openedAt.toLocal()}'),
                Text('Opening cash: ${money(s.shift.openingCashMinor)} THB'),
                Text('Sales: ${s.salesCount}'),
                Text('Gross sales: ${money(s.grossSalesMinor)} THB'),
                Text('Cash in: ${money(s.cashInMinor)} THB'),
                Text('Cash out: ${money(s.cashOutMinor)} THB'),
                Text('Expected cash: ${money(s.expectedCashMinor)} THB'),
                Text('Sync: ${_syncStatus(syncPending)}'),
                FilledButton(
                  onPressed: () => context.push('/sale'),
                  child: const Text('Start Sale'),
                ),
                FilledButton.tonal(
                  onPressed: () => context.push('/shift/$shiftId/cash/cash_in'),
                  child: const Text('Cash In'),
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      context.push('/shift/$shiftId/cash/cash_out'),
                  child: const Text('Cash Out'),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/shift/$shiftId/close'),
                  child: const Text('Close Shift'),
                ),
              ],
            ),
          ),
    );
  }
}

class CashMovementScreen extends ConsumerStatefulWidget {
  const CashMovementScreen({
    required this.shiftId,
    required this.type,
    super.key,
  });
  final String shiftId, type;
  @override
  ConsumerState<CashMovementScreen> createState() => _CashMovementState();
}

class _CashMovementState extends ConsumerState<CashMovementScreen> {
  final amount = TextEditingController(), note = TextEditingController();
  late String type;
  String reason = 'other';
  String? error;
  @override
  void initState() {
    super.initState();
    type = widget.type;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    try {
      final shift = await ref
          .read(shiftRepositoryProvider)
          .getShiftById(widget.shiftId);
      if (shift == null) throw const ShiftException('No open shift');
      await ref
          .read(cashMovementServiceProvider)
          .record(
            shiftId: shift.id,
            branchId: shift.branchId,
            deviceId: shift.deviceId,
            type: type,
            amountMinor: MoneyParser.parseMinor(amount.text),
            reasonCode: reason,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          );
      ref.invalidate(shiftSummaryProvider(widget.shiftId));
      ref.invalidate(shiftSyncPendingProvider(widget.shiftId));
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(type == 'cash_in' ? 'Cash In' : 'Cash Out')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButtonFormField<String>(
          key: const Key('cash-movement-type'),
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Movement type'),
          items: const [
            DropdownMenuItem(value: 'cash_in', child: Text('Cash In')),
            DropdownMenuItem(value: 'cash_out', child: Text('Cash Out')),
          ],
          onChanged: (value) => setState(() => type = value!),
        ),
        DropdownButtonFormField(
          initialValue: reason,
          items: [
            for (final r in cashReasonCodes)
              DropdownMenuItem(value: r, child: Text(r)),
          ],
          onChanged: (v) => setState(() => reason = v!),
        ),
        TextField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(onPressed: save, child: const Text('Confirm')),
      ],
    ),
  );
}

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({required this.shiftId, super.key});
  final String shiftId;
  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftState();
}

class _CloseShiftState extends ConsumerState<CloseShiftScreen> {
  final closing = TextEditingController();
  String? error;
  @override
  void dispose() {
    closing.dispose();
    super.dispose();
  }

  int? parsed() {
    try {
      return MoneyParser.parseMinor(closing.text);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    try {
      await ref
          .read(closeShiftServiceProvider)
          .close(widget.shiftId, MoneyParser.parseMinor(closing.text));
      ref.invalidate(shiftSummaryProvider(widget.shiftId));
      ref.invalidate(shiftSyncPendingProvider(widget.shiftId));
      ref.invalidate(openShiftProvider);
      ref.invalidate(recentShiftsProvider);
      if (mounted) context.go('/shift/${widget.shiftId}');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Close Shift')),
    body: ref
        .watch(shiftSummaryProvider(widget.shiftId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Unable to load summary')),
          data: (s) {
            final actual = parsed();
            final difference = actual == null
                ? null
                : actual - s.expectedCashMinor;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Opening cash: ${money(s.shift.openingCashMinor)} THB'),
                Text('Cash sales: ${money(s.cashSalesMinor)} THB'),
                Text('Cash in: ${money(s.cashInMinor)} THB'),
                Text('Cash out: ${money(s.cashOutMinor)} THB'),
                Text('Expected cash: ${money(s.expectedCashMinor)} THB'),
                TextField(
                  controller: closing,
                  decoration: const InputDecoration(labelText: 'Closing cash'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (difference != null)
                  Text('Difference: ${money(difference)} THB'),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: close,
                  child: const Text('Close shift'),
                ),
              ],
            );
          },
        ),
  );
}

class ShiftHistoryScreen extends ConsumerWidget {
  const ShiftHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Shift History')),
    body: ref
        .watch(recentShiftsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Unable to load shifts')),
          data: (rows) => ListView(
            children: [
              for (final s in rows)
                FutureBuilder<ShiftSummary>(
                  future: ref.read(shiftSummaryServiceProvider).get(s.id),
                  builder: (context, snapshot) {
                    final summary = snapshot.data;
                    final syncPending = ref.watch(
                      shiftSyncPendingProvider(s.id),
                    );
                    return ListTile(
                      title: Text('${s.openedAt.toLocal()} — ${s.status}'),
                      subtitle: Text(
                        'Closed ${s.closedAt?.toLocal() ?? '-'}\n'
                        'Gross ${money(summary?.grossSalesMinor ?? 0)} • '
                        'Expected ${money(s.expectedCashMinor ?? summary?.expectedCashMinor ?? 0)} • '
                        'Closing ${money(s.closingCashMinor ?? 0)} • '
                        'Difference ${money(s.cashDifferenceMinor ?? 0)} • '
                        'Sync ${_syncStatus(syncPending).toLowerCase()}',
                      ),
                      isThreeLine: true,
                      onTap: () => context.push('/shift/${s.id}'),
                    );
                  },
                ),
            ],
          ),
        ),
  );
}

class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({required this.shiftId, super.key});
  final String shiftId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncPending = ref.watch(shiftSyncPendingProvider(shiftId));
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Detail')),
      body: ref
          .watch(shiftSummaryProvider(shiftId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Unable to load shift detail')),
            data: (s) => FutureBuilder(
              future: Future.wait([
                ref
                    .read(shiftRepositoryProvider)
                    .getShiftCashMovements(shiftId),
                ref.read(shiftRepositoryProvider).getShiftSales(shiftId),
              ]),
              builder: (context, snapshot) {
                final movements = snapshot.data?[0] ?? [];
                final sales = snapshot.data?[1] ?? [];
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Status: ${s.shift.status}'),
                    Text('Gross sales: ${money(s.grossSalesMinor)} THB'),
                    Text('Expected cash: ${money(s.expectedCashMinor)} THB'),
                    Text('Closing cash: ${money(s.closingCashMinor ?? 0)} THB'),
                    Text(
                      'Difference: ${money(s.cashDifferenceMinor ?? 0)} THB',
                    ),
                    Text('Sync: ${_syncStatus(syncPending)}'),
                    if (s.shift.status == 'closed') ...[
                      FilledButton(
                        onPressed: () => context.go('/shift'),
                        child: const Text('Start New Shift'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/shifts'),
                        child: const Text('Shift History'),
                      ),
                    ],
                    const Divider(),
                    const Text('Cash movements'),
                    for (final m in movements)
                      Text(
                        '${(m as dynamic).type}: ${money((m as dynamic).amountMinor)}',
                      ),
                    const Divider(),
                    const Text('Sales'),
                    for (final sale in sales)
                      Text(
                        '${(sale as dynamic).receiptNumber}: ${money((sale as dynamic).totalMinor)}',
                      ),
                  ],
                );
              },
            ),
          ),
    );
  }
}
