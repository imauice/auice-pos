class AppConfig {
  const AppConfig({required this.apiBaseUrl});
  final String apiBaseUrl;
  static const current = AppConfig(apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api'));
}

