import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_token.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  String? _clientId;
  String? _token;
  bool _isLoading = false;
  String? _error;

  String? get clientId => _clientId;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  AuthProvider() {
    _loadSavedAuth();
  }

  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      _clientId = prefs.getString('client_id');
      if (_token != null) {
        apiClient.setToken(_token);
        // Recover client_id from server if it wasn't stored locally
        // (happens with sessions created before client_id was persisted)
        if (_clientId == null || _clientId!.isEmpty) {
          await _recoverClientId(prefs);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _recoverClientId(SharedPreferences prefs) async {
    try {
      final data = await apiClient.get('api/client/me');
      if (data is Map<String, dynamic>) {
        final id = data['id']?.toString();
        if (id != null && id.isNotEmpty) {
          _clientId = id;
          await prefs.setString('client_id', id);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString('auth_token', _token!);
      } else {
        await prefs.remove('auth_token');
      }
      if (_clientId != null) {
        await prefs.setString('client_id', _clientId!);
      } else {
        await prefs.remove('client_id');
      }
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authToken = await _authService.login(email, password);
      _token = authToken.token;
      _clientId = authToken.clientId;
      apiClient.setToken(_token);
      await _saveAuth();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final raw = e.toString();
      // Strip technical prefix: "ApiException(401): ..." → "..."
      final match = RegExp(r'ApiException\(\d+\):\s*').firstMatch(raw);
      _error = match != null ? raw.substring(match.end) : raw.replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Demo/preview login
  void loginDemo() {
    _token = 'demo-token-preview';
    _clientId = 'demo';
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _clientId = null;
    apiClient.setToken(null);
    await _saveAuth();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
