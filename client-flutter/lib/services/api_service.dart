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

  void setAuthToken(String token) => _authToken = token;
  void clearAuthToken() => _authToken = null;

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) h[ApiConfig.authHeader] = _authToken!;
    return h;
  }

  Uri _uri(String endpoint, [Map<String, String>? q]) {
    final url = '${ApiConfig.baseUrl}$endpoint';
    if (q != null && q.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: q);
    }
    return Uri.parse(url);
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      final res = await http.get(_uri(endpoint, queryParams), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final res = await http
          .post(_uri(endpoint), headers: _headers,
              body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final res = await http
          .put(_uri(endpoint), headers: _headers,
              body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 30));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final res = await http.delete(_uri(endpoint), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  dynamic _handle(http.Response res) {
    final code = res.statusCode;
    if (code >= 200 && code < 300) {
      if (res.body.isEmpty) return null;
      try {
        return jsonDecode(res.body);
      } catch (_) {
        return res.body;
      }
    }
    String msg = 'Request failed';
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b.containsKey('message')) msg = b['message'].toString();
      if (b is Map && b.containsKey('error')) msg = b['error'].toString();
    } catch (_) {}
    if (code == 401) throw ApiException('Bitte erneut anmelden.', statusCode: code);
    if (code == 403) throw ApiException('Zugriff verweigert.', statusCode: code);
    if (code == 404) throw ApiException('Nicht gefunden.', statusCode: code);
    if (code >= 500) throw ApiException('Serverfehler. Bitte später versuchen.', statusCode: code);
    throw ApiException(msg, statusCode: code);
  }
}
