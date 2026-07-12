import 'package:auice_pos/config/app_config.dart';
import 'package:dio/dio.dart';

class CloudHealthClient {
  CloudHealthClient({Dio? dio, AppConfig config = AppConfig.current})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: config.apiBaseUrl));
  final Dio _dio;
  Future<void> check() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    if (response.statusCode != 200 || response.data?['status'] != 'ok') {
      throw StateError('Cloud health check failed');
    }
  }
}
