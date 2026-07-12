import 'package:auice_pos/core/network/cloud_health_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CloudConnectionStatus { notChecked, loading, online, offline }
class CloudConnectionState {
  const CloudConnectionState(this.status, {this.lastChecked});
  final CloudConnectionStatus status;
  final DateTime? lastChecked;
}
final cloudHealthClientProvider = Provider((ref) => CloudHealthClient());
final cloudConnectionProvider = StateNotifierProvider<CloudConnectionController, CloudConnectionState>((ref) => CloudConnectionController(ref.read(cloudHealthClientProvider)));
class CloudConnectionController extends StateNotifier<CloudConnectionState> {
  CloudConnectionController(this._client) : super(const CloudConnectionState(CloudConnectionStatus.notChecked));
  final CloudHealthClient _client;
  Future<void> check() async {
    state = CloudConnectionState(CloudConnectionStatus.loading, lastChecked: state.lastChecked);
    try { await _client.check(); state = CloudConnectionState(CloudConnectionStatus.online, lastChecked: DateTime.now()); }
    catch (_) { state = CloudConnectionState(CloudConnectionStatus.offline, lastChecked: DateTime.now()); }
  }
}

