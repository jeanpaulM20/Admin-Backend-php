import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/glucose_reading.dart';
import '../models/libre_auth.dart';

/// HTTP-Client für die inoffizielle LibreLinkUp API.
/// HINWEIS: Inoffizielle API — kann sich jederzeit ändern (kein Support durch Abbott).
class LibreApiClient {
  // LibreView erwartet diese Headers — ohne sie wird der Request abgelehnt.
  static const _appProduct = 'llu.ios';
  static const _appVersion = '4.12.0';
  static const _timeout = Duration(seconds: 15);

  final LibreRegion region;

  LibreApiClient({this.region = LibreRegion.eu});

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'product': _appProduct,
        'version': _appVersion,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${region.baseUrl}$path');

  // MARK: - Auth

  /// Login — gibt ein AuthTicket zurück.
  /// Wirft [LibreApiException] bei Fehler.
  Future<LibreAuthTicket> login(String email, String password) async {
    final response = await http
        .post(
          _uri('/llu/auth/login'),
          headers: _headers(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    final body = _decode(response);
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw LibreApiException(0, 'Ungültige Login-Antwort');
    return LibreAuthTicket.fromJson(data);
  }

  // MARK: - Connections

  /// Gibt die Liste aller verbundenen Libre-Profile zurück.
  Future<List<LibreConnection>> getConnections(String token) async {
    final response = await http
        .get(_uri('/llu/connections'), headers: _headers(token: token))
        .timeout(_timeout);

    final body = _decode(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(LibreConnection.fromJson)
        .toList();
  }

  // MARK: - Glukose-Daten

  /// Aktuelle Messung + letzten ~8h Verlauf für eine Connection.
  Future<List<GlucoseReading>> getGraphData(
      String token, String patientId) async {
    final response = await http
        .get(
          _uri('/llu/connections/$patientId/graph'),
          headers: _headers(token: token),
        )
        .timeout(_timeout);

    final body = _decode(response);
    final data = body['data'] as Map<String, dynamic>?;
    final graphData = data?['graphData'] as List<dynamic>? ?? [];
    final readings = graphData
        .whereType<Map<String, dynamic>>()
        .map(GlucoseReading.fromJson)
        .toList();

    // Aktuelle Messung aus Connection-Daten ergänzen, falls vorhanden
    final current = (data?['connection'] as Map<String, dynamic>?)?
        ['glucoseMeasurement'] as Map<String, dynamic>?;
    if (current != null) {
      final currentReading = GlucoseReading.fromJson(current);
      if (readings.isEmpty ||
          currentReading.timestamp.isAfter(readings.last.timestamp)) {
        readings.add(currentReading);
      }
    }

    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return readings;
  }

  // MARK: - Intern

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 401) {
      throw LibreApiException(401, 'Nicht autorisiert — bitte erneut einloggen');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LibreApiException(
          response.statusCode, 'Serverfehler (${response.statusCode})');
    }
    try {
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      final status = parsed['status'] as int? ?? 0;
      if (status != 0) {
        throw LibreApiException(status, 'API-Fehler (Status $status)');
      }
      return parsed;
    } catch (e) {
      if (e is LibreApiException) rethrow;
      throw LibreApiException(-1, 'Antwort konnte nicht gelesen werden');
    }
  }
}

class LibreApiException implements Exception {
  final int code;
  final String message;
  const LibreApiException(this.code, this.message);
  @override
  String toString() => 'LibreApiException($code): $message';
}
