import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers[ApiConfig.authHeader] = _token!;
    }
    return headers;
  }

  Uri _buildUri(String path) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl
        : '${ApiConfig.baseUrl}/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base$cleanPath');
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw ApiException(401, 'Nicht autorisiert. Bitte erneut anmelden.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String msg = 'Serverfehler (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          msg = body['message'].toString();
        }
      } catch (_) {}
      throw ApiException(response.statusCode, msg);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<dynamic> get(String path) async {
    final response = await http
        .get(_buildUri(path), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _decodeResponse(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .post(
          _buildUri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(ApiConfig.timeout);
    return _decodeResponse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .put(
          _buildUri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(ApiConfig.timeout);
    return _decodeResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http
        .delete(_buildUri(path), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _decodeResponse(response);
  }
}

// Singleton instance
final apiClient = ApiClient();
