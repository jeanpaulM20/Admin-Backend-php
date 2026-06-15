import 'package:flutter/foundation.dart';
import '../models/glucose_reading.dart';
import '../models/libre_auth.dart';
import '../repositories/libre_repository.dart';

/// State-Management für FreeStyle Libre CGM-Daten.
/// Pendant zur bestehenden Provider-Architektur (ChangeNotifier).
class LibreProvider extends ChangeNotifier {
  final LibreRepository _repo;

  LibreProvider({LibreRepository? repository})
      : _repo = repository ?? LibreRepository();

  List<GlucoseReading> _readings = [];
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _error;
  DateTime? _lastSync;
  bool _fromCache = false;

  List<GlucoseReading> get readings => _readings;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get fromCache => _fromCache;

  GlucoseReading? get latestReading =>
      _readings.isEmpty ? null : _readings.last;

  LibreProvider() : _repo = LibreRepository() {
    _init();
  }

  Future<void> _init() async {
    _isLoggedIn = await _repo.isLoggedIn;
    if (_isLoggedIn) await loadReadings();
    notifyListeners();
  }

  // MARK: - Auth

  Future<bool> login(String email, String password,
      {LibreRegion region = LibreRegion.eu}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.login(email, password, region: region);
      _isLoggedIn = true;
      await loadReadings();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _readings = [];
    _isLoggedIn = false;
    _lastSync = null;
    _error = null;
    notifyListeners();
  }

  // MARK: - Daten laden

  Future<void> loadReadings({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repo.getReadings(forceRefresh: forceRefresh);
      _readings = result.readings;
      _lastSync = result.lastSync;
      _fromCache = result.fromCache;
      if (result.error != null) _error = result.error;
    } catch (e) {
      _error = _friendlyError(e);
      if (e.toString().contains('401')) _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Sitzung abgelaufen — bitte neu einloggen';
    if (msg.contains('SocketException') || msg.contains('timeout')) {
      return 'Keine Verbindung — lokale Daten werden angezeigt';
    }
    return msg.replaceFirst('LibreApiException(\\d+): ', '');
  }
}
