import 'dart:async';
import 'package:auice_pos/core/catalog/catalog_gateway.dart';
import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:auice_pos/core/database/app_database.dart';
import 'package:auice_pos/features/startup/startup_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledGateway implements CatalogGateway {
  final registration = Completer<RegistrationResult>();
  final page = Completer<CatalogPage>();

  @override
  Future<bool> isOnline() async => true;
  @override
  Future<RegistrationResult> register(String deviceId) => registration.future;
  @override
  Future<Map<String, dynamic>> fetchBranch(String branchId) async => {
    'id': branchId,
    'code': 'BKK01',
    'name': 'Bangkok',
    'timezone': 'Asia/Bangkok',
    'currency': 'THB',
    'active': true,
    'version': 1,
    'updatedAt': '2026-01-01T00:00:00.000Z',
  };
  @override
  Future<CatalogPage> pull({
    required String branchId,
    required int fromVersion,
    String? cursor,
  }) => page.future;
}

void main() {
  testWidgets('actual startup screen renders provider-driven transitions', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = ControlledGateway();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          catalogGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: StartupScreen()),
      ),
    );
    expect(find.text('Auice POS'), findsWidgets);
    expect(find.text('Local-first point of sale'), findsOneWidget);
    expect(find.text('Local Database: Ready'), findsOneWidget);
    expect(find.text('Cloud Connection: Not checked'), findsOneWidget);
    expect(find.text('Sync Status: Idle'), findsOneWidget);
    expect(find.text('Check Cloud Connection'), findsOneWidget);
    await tester.pump();
    expect(find.text('Catalog: Registering device'), findsOneWidget);

    gateway.registration.complete(
      const RegistrationResult(branchId: 'branch', catalogVersion: 1),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Catalog: Updating catalog'), findsOneWidget);

    gateway.page.complete(
      CatalogPage(
        fromVersion: 0,
        targetVersion: 1,
        hasMore: false,
        categories: const [],
        products: const [],
        productUnits: const [],
        productPrices: const [],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Catalog: Ready online'), findsOneWidget);
  });
}
