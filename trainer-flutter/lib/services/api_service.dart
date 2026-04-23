import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ApiService {
  static ApiService? _instance;
  String? _authToken;

  ApiService._internal();

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers[ApiConfig.authHeader] = _authToken!;
    }
    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final url = '${ApiConfig.baseUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }
    return Uri.parse(url);
  }

  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> delete(String endpoint,
      {Map<String, String>? queryParams}) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// POST with application/x-www-form-urlencoded (required for PHP $_POST reads)
  Future<dynamic> postForm(String endpoint,
      {Map<String, String>? body}) async {
    try {
      final uri = _buildUri(endpoint);
      final formHeaders = <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };
      if (_authToken != null) {
        formHeaders[ApiConfig.authHeader] = _authToken!;
      }
      final response = await http
          .post(uri, headers: formHeaders, body: body)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } else if (statusCode == 401) {
      throw ApiException('Unauthorized. Please log in again.',
          statusCode: statusCode);
    } else if (statusCode == 403) {
      throw ApiException('Access denied.', statusCode: statusCode);
    } else if (statusCode == 404) {
      throw ApiException('Resource not found.', statusCode: statusCode);
    } else if (statusCode >= 500) {
      throw ApiException('Server error. Please try again later.',
          statusCode: statusCode);
    } else {
      String message = 'Request failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw ApiException(message, statusCode: statusCode);
    }
  }
}
