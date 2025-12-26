/// API Configuration for WaqiKids Child App
class ApiConfig {
  // Environment detection
  static const bool isProduction = bool.fromEnvironment('dart.vm.product'); 

  // API URLs - Using dns.waqikids.com with HTTPS
  static const String _developmentUrl = 'https://dns.waqikids.com/api';
  static const String _productionUrl = 'https://dns.waqikids.com/api';   

  static String get baseUrl => isProduction ? _productionUrl : _developmentUrl;
  
  // API Key for authentication
  static const String apiKey = 'waqikids_secure_2024_local_api_key_do_not_share_f8a3c9d1';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration syncInterval = Duration(minutes: 5);
}
