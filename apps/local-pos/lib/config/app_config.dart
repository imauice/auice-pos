class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.branchCode = 'BKK01',
    this.deviceName = 'Auice POS',
    this.platform = 'unknown',
    this.appVersion = '0.1.0',
  });
  final String apiBaseUrl, branchCode, deviceName, platform, appVersion;
  static const current = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/api',
    ),
    branchCode: String.fromEnvironment('BRANCH_CODE', defaultValue: 'BKK01'),
    deviceName: String.fromEnvironment(
      'DEVICE_NAME',
      defaultValue: 'Auice POS',
    ),
    platform: String.fromEnvironment(
      'DEVICE_PLATFORM',
      defaultValue: 'unknown',
    ),
    appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
  );
}
