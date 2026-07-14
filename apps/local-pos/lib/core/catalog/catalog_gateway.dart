import 'package:auice_pos/config/app_config.dart';
import 'package:auice_pos/core/catalog/catalog_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegistrationResult {
  const RegistrationResult({
    required this.branchId,
    required this.catalogVersion,
  });
  final String branchId;
  final int catalogVersion;
}

abstract class CatalogGateway {
  Future<bool> isOnline();
  Future<RegistrationResult> register(String deviceId);
  Future<Map<String, dynamic>> fetchBranch(String branchId);
  Future<CatalogPage> pull({
    required String branchId,
    required int fromVersion,
    String? cursor,
  });
}

class DioCatalogGateway implements CatalogGateway {
  DioCatalogGateway({Dio? dio, this.config = AppConfig.current})
    : dio = dio ?? Dio(BaseOptions(baseUrl: config.apiBaseUrl));
  final Dio dio;
  final AppConfig config;
  @override
  Future<bool> isOnline() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RegistrationResult> register(String deviceId) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/device/register',
      data: {
        'deviceId': deviceId,
        'branchCode': config.branchCode,
        'deviceName': config.deviceName,
        'platform': config.platform,
        'appVersion': config.appVersion,
      },
    );
    final data = response.data!;
    return RegistrationResult(
      branchId: data['branchId'] as String,
      catalogVersion: data['catalogVersion'] as int,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchBranch(String branchId) async {
    final response = await dio.get<Map<String, dynamic>>('/branches/$branchId');
    return response.data!;
  }

  @override
  Future<CatalogPage> pull({
    required String branchId,
    required int fromVersion,
    String? cursor,
  }) async {
    final parameters = <String, dynamic>{
      'branchId': branchId,
      'catalogVersion': fromVersion,
      'limit': 100,
    };
    if (cursor != null) {
      parameters['cursor'] = cursor;
    }
    final response = await dio.get<Map<String, dynamic>>(
      '/catalog',
      queryParameters: parameters,
    );
    return CatalogPage.fromJson(response.data!);
  }
}

final catalogGatewayProvider = Provider<CatalogGateway>((ref) {
  final gateway = DioCatalogGateway();
  ref.onDispose(gateway.dio.close);
  return gateway;
});
