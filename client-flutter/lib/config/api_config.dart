/// API configuration pointing to Railway NestJS backend
class ApiConfig {
  ApiConfig._();

  /// Railway NestJS backend
  static const String baseUrl =
      'https://admin-backend-php-production.up.railway.app/';

  /// Auth header name (token-based auth)
  static const String authHeader = 'X-Auth-Token';

  /// Request timeout
  static const Duration timeout = Duration(seconds: 15);
}
