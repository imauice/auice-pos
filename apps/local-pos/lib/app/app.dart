import 'package:auice_pos/features/startup/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
final _router = GoRouter(routes: [GoRoute(path: '/', builder: (context, state) => const StartupScreen())]);
class AuicePosApp extends StatelessWidget {
  const AuicePosApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp.router(title: 'Auice POS', theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b63))), routerConfig: _router);
}
