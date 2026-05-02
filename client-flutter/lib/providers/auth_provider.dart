import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  ClientModel? _client;
  String? _error;
  bool _loading = false;

  AuthStatus get status  => _status;
  ClientModel? get client => _client;
  String? get error      => _error;
  bool get isLoading     => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  int? get clientId      => _client?.id;

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    try {
      final ok = await _auth.restoreSession();
      if (ok) {
        final c = await _auth.getStoredClient();
        if (c != null) {
          _client = c;
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phone, String passcode) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _client = await _auth.login(phone, passcode);
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      return false;
    } catch (e) {
      _error = 'Anmeldung fehlgeschlagen.';
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _client = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
