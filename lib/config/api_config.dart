/// API Configuration for WaqiKids Child App
class ApiConfig {
  // Environment detection
  static const bool isProduction = bool.fromEnvironment('dart.vm.product'); 

  // API URLs - Both pointing to Hetzner for testing
  static const String _developmentUrl = 'http://178.156.160.245:8080/api';
  static const String _productionUrl = 'http://178.156.160.245:8080/api';   

  static String get baseUrl => isProduction ? _productionUrl : _developmentUrl;
  
  // API Key for authentication
  static const String apiKey = 'waqikids_secure_2024_local_api_key_do_not_share_f8a3c9d1';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration syncInterval = Duration(minutes: 5);
}
