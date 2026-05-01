import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/appointment.dart';
import '../models/client_model.dart';
import '../services/api_service.dart';

class ClientProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _loading = false;
  String? _error;

  // Dashboard
  List<Appointment> _upcoming = [];
  int _credits = 0;

  // Calendar data
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _trainingTypes = [];
  List<Map<String, dynamic>> _availability = [];
  List<Appointment> _allAppointments = [];

  // Profile
  ClientModel? _profile;
  List<Map<String, dynamic>> _creditPacks = [];

  bool get isLoading => _loading;
  String? get error  => _error;
  List<Appointment> get upcoming => _upcoming;
  int get credits => _credits;
  List<Map<String, dynamic>> get trainers => _trainers;
  List<Map<String, dynamic>> get trainingTypes => _trainingTypes;
  List<Map<String, dynamic>> get availability => _availability;
  List<Appointment> get allAppointments => _allAppointments;
  ClientModel? get profile => _profile;
  List<Map<String, dynamic>> get creditPacks => _creditPacks;

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<void> fetchStart(int clientId) async {
    _setLoading(true);
    try {
      final r = await _api.get(ApiConfig.start(clientId));
      final data = _map(r);
      if (data != null) {
        _credits = _parseInt(data['credits'] ?? data['credit_count'] ?? 0);
        final rawApps = data['appointments'] ?? data['trainings'] ?? [];
        _upcoming = _parseList(rawApps);
        _allAppointments = _upcoming;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Fehler beim Laden der Startdaten.';
    } finally {
      _setLoading(false);
    }
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  Future<void> fetchCalendar(int clientId) async {
    _setLoading(true);
    try {
      final r = await _api.get(ApiConfig.calendar(clientId));
      final data = _map(r);
      if (data != null) {
        _trainers = _mapList(data['trainers']);
        _trainingTypes = _mapList(data['training_types'] ?? data['types']);
        _availability = _mapList(data['availability']);
        _allAppointments = _parseList(data['appointments'] ?? data['trainings'] ?? []);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Fehler beim Laden des Kalenders.';
    } finally {
      _setLoading(false);
    }
  }

  Future<Appointment?> bookAppointment(int clientId, Map<String, dynamic> body) async {
    try {
      final r = await _api.post(ApiConfig.bookAppointment(clientId), body: body);
      final data = _map(r);
      if (data != null) return Appointment.fromJson(data);
      return null;
    } on ApiException {
      rethrow;
    }
  }

  Future<bool> cancelAppointment(int clientId, int appointmentId) async {
    try {
      await _api.delete(ApiConfig.cancelAppointment(clientId, appointmentId));
      _allAppointments.removeWhere((a) => a.id == appointmentId);
      _upcoming.removeWhere((a) => a.id == appointmentId);
      notifyListeners();
      return true;
    } on ApiException {
      rethrow;
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<void> fetchProfile(int clientId) async {
    _setLoading(true);
    try {
      final r = await _api.get(ApiConfig.profile(clientId));
      final data = _map(r);
      if (data != null) {
        _profile = ClientModel.fromJson(data);
        _credits = _parseInt(data['credits'] ?? data['credit_count'] ?? _credits);
        _creditPacks = _mapList(data['credit_packs'] ?? data['subscriptions'] ?? []);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Fehler beim Laden des Profils.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchCredits(int clientId) async {
    try {
      final r = await _api.get(ApiConfig.credits(clientId));
      if (r is List) {
        _creditPacks = r.whereType<Map<String, dynamic>>().toList();
      } else if (r is Map<String, dynamic>) {
        _creditPacks = _mapList(r['data'] ?? r['packs'] ?? []);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _loading = v;
    if (v) _error = null;
    notifyListeners();
  }

  Map<String, dynamic>? _map(dynamic r) {
    if (r is Map<String, dynamic>) return r;
    if (r is List && r.isNotEmpty && r[0] is Map) return r[0] as Map<String, dynamic>;
    return null;
  }

  List<Map<String, dynamic>> _mapList(dynamic r) {
    if (r is List) return r.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  List<Appointment> _parseList(dynamic r) {
    if (r is List) {
      return r
          .whereType<Map<String, dynamic>>()
          .map((e) => Appointment.fromJson(e))
          .toList();
    }
    return [];
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
