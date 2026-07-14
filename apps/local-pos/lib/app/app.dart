import 'package:auice_pos/features/startup/startup_screen.dart';
import 'package:auice_pos/features/sale/payment_screen.dart';
import 'package:auice_pos/features/sale/receipt_screen.dart';
import 'package:auice_pos/features/sale/sale_screen.dart';
import 'package:auice_pos/features/shift/shift_screens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter _createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartupScreen()),
    GoRoute(path: '/sale', builder: (context, state) => const SaleScreen()),
    GoRoute(
      path: '/shift',
      builder: (context, state) => const ShiftGateScreen(),
    ),
    GoRoute(
      path: '/shifts',
      builder: (context, state) => const ShiftHistoryScreen(),
    ),
    GoRoute(
      path: '/shift/:id',
      builder: (context, state) =>
          ShiftDetailScreen(shiftId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/shift/:id/close',
      builder: (context, state) =>
          CloseShiftScreen(shiftId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/shift/:id/cash/:type',
      builder: (context, state) => CashMovementScreen(
        shiftId: state.pathParameters['id']!,
        type: state.pathParameters['type']!,
      ),
    ),
    GoRoute(
      path: '/payment',
      builder: (context, state) => const PaymentScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const SaleHistoryScreen(),
    ),
    GoRoute(
      path: '/receipt/:id',
      builder: (context, state) =>
          ReceiptScreen(saleId: state.pathParameters['id']!),
    ),
  ],
);

class AuicePosApp extends StatefulWidget {
  const AuicePosApp({super.key});

  @override
  State<AuicePosApp> createState() => _AuicePosAppState();
}

class _AuicePosAppState extends State<AuicePosApp> {
  late final GoRouter router = _createRouter();

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Auice POS',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b63)),
    ),
    routerConfig: router,
  );
}
