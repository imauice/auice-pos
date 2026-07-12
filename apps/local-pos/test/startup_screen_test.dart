import 'package:auice_pos/features/startup/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  testWidgets('renders startup foundation and initial cloud state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: StartupScreen())));
    expect(find.text('Auice POS'), findsWidgets);
    expect(find.text('Local-first point of sale'), findsOneWidget);
    expect(find.text('Local Database: Ready'), findsOneWidget);
    expect(find.text('Cloud Connection: Not checked'), findsOneWidget);
    expect(find.text('Sync Status: Idle'), findsOneWidget);
    expect(find.text('Check Cloud Connection'), findsOneWidget);
  });
}

