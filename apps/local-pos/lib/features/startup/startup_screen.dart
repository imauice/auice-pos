import 'package:auice_pos/features/startup/cloud_connection_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudConnectionProvider);
    final label = switch (cloud.status) {
      CloudConnectionStatus.notChecked => 'Not checked',
      CloudConnectionStatus.loading => 'Loading',
      CloudConnectionStatus.online => 'Online',
      CloudConnectionStatus.offline => 'Offline',
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
            ],
          ),
        ),
      ),
    );
  }
}
