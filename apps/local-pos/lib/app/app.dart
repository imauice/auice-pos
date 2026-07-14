import 'package:auice_pos/features/startup/startup_screen.dart';
import 'package:auice_pos/features/sale/payment_screen.dart';
import 'package:auice_pos/features/sale/receipt_screen.dart';
import 'package:auice_pos/features/sale/sale_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartupScreen()),
    GoRoute(path: '/sale', builder: (context, state) => const SaleScreen()),
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

class AuicePosApp extends StatelessWidget {
  const AuicePosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Auice POS',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b63)),
    ),
    routerConfig: _router,
  );
}
