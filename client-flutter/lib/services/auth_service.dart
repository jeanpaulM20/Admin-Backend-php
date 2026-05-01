import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/client_model.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey   = 'client_auth_token';
  static const String _clientKey  = 'client_data';
  static const String _clientIdKey = 'client_id';

  final ApiService _api = ApiService();

  /// Login with phone and passcode.
  /// PHP returns { token: "...", client: { id: ... } }
  Future<ClientModel> login(String phone, String passcode) async {
    final response = await _api.post(ApiConfig.token, body: {
      'phone': phone,
      'passcode': passcode,
    });

    if (response == null) throw ApiException('Keine Antwort vom Server');

    final Map<String, dynamic> data;
    if (response is Map<String, dynamic>) {
      data = response;
    } else {
      throw ApiException('Ungültiges Antwortformat');
    }

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Ungültige Anmeldedaten');
    }

    // Extract client ID
    final clientData = data['client'] as Map<String, dynamic>?;
    int parseId(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    final clientId = clientData != null
        ? parseId(clientData['id'])
        : parseId(data['client_id'] ?? data['id'] ?? 0);

    if (clientId == 0) throw ApiException('Client-ID fehlt in der Antwort');

    // Set token for subsequent requests
    _api.setAuthToken(token);

    // Fetch full profile
    ClientModel client;
    try {
      final profileResp = await _api.get(ApiConfig.profile(clientId));
      final profileData = _extractFirst(profileResp);
      client = ClientModel.fromJson(profileData ?? (clientData ?? {'id': clientId}));
    } catch (_) {
      client = ClientModel.fromJson(clientData ?? {'id': clientId});
    }

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_clientIdKey, clientId);
    await prefs.setString(_clientKey, jsonEncode({'id': clientId, 'firstname': client.firstname, 'lastname': client.lastname, 'email': client.email, 'phone': client.phone, 'photo': client.photo}));

    return client;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_clientKey);
    await prefs.remove(_clientIdKey);
    _api.clearAuthToken();
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return false;
    _api.setAuthToken(token);
    return true;
  }

  Future<ClientModel?> getStoredClient() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_clientKey);
    if (json == null) return null;
    try {
      return ClientModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getStoredClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_clientIdKey);
  }

  Map<String, dynamic>? _extractFirst(dynamic r) {
    if (r is Map<String, dynamic>) return r;
    if (r is List && r.isNotEmpty) return r[0] as Map<String, dynamic>?;
    return null;
  }
}
