import 'dart:async';
import 'package:auice_pos/features/startup/catalog_startup_coordinator.dart';
import 'package:auice_pos/features/startup/cloud_connection_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});
  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        unawaited(ref.read(catalogStartupStateProvider.notifier).start());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(cloudConnectionProvider);
    final catalog = ref.watch(catalogStartupStateProvider);
    final label = switch (cloud.status) {
      CloudConnectionStatus.notChecked => 'Not checked',
      CloudConnectionStatus.loading => 'Loading',
      CloudConnectionStatus.online => 'Online',
      CloudConnectionStatus.offline => 'Offline',
    };
    final catalogLabel = switch (catalog) {
      CatalogStartupState.firstRunNeedsConnection =>
        'Setup required: connect to register and download catalog',
      CatalogStartupState.readyOffline => 'Ready offline',
      CatalogStartupState.readyOnline => 'Ready online',
      CatalogStartupState.syncFailedUsingLocal =>
        'Sync failed; using local catalog',
      CatalogStartupState.loadingLocal => 'Loading local catalog',
      CatalogStartupState.registering => 'Registering device',
      CatalogStartupState.syncingCatalog => 'Updating catalog',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Auice POS')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auice POS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text('Local-first point of sale'),
              const SizedBox(height: 24),
              const Text('Local Database: Ready'),
              Text('Cloud Connection: $label'),
              Text('Catalog: $catalogLabel'),
              const Text('Sync Status: Idle'),
              if (cloud.lastChecked != null)
                Text('Last checked: ${cloud.lastChecked!.toLocal()}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: cloud.status == CloudConnectionStatus.loading
                    ? null
                    : () => ref.read(cloudConnectionProvider.notifier).check(),
                child: const Text('Check Cloud Connection'),
              ),
              FilledButton.tonal(
                onPressed: () => context.go('/sale'),
                child: const Text('Open Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
