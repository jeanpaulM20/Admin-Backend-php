import 'package:flutter/foundation.dart';
import '../services/preference_service.dart';

/// Manages booking preferences (default trainer, training type, location).
/// Loads from backend on first access, caches locally, syncs on change.
class PreferenceProvider extends ChangeNotifier {
  final PreferenceService _service = PreferenceService();

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  String? _trainerId;
  String? _trainingTypeId;
  String? _locationId;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  String? get trainerId => _trainerId;
  String? get trainingTypeId => _trainingTypeId;
  String? get locationId => _locationId;

  /// Load preferences from backend (skips if already loaded)
  Future<void> load(String clientId, {bool force = false}) async {
    if (_isLoaded && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await _service.getPreferences(clientId);
      _trainerId = prefs['trainer_id'];
      _trainingTypeId = prefs['training_type_id'];
      _locationId = prefs['location_id'];
      _isLoaded = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save a single preference and sync to backend
  Future<void> setPreference(String clientId, String key, String? value) async {
    // Update local state immediately (optimistic)
    switch (key) {
      case 'trainer_id':
        _trainerId = value;
        break;
      case 'training_type_id':
        _trainingTypeId = value;
        break;
      case 'location_id':
        _locationId = value;
        break;
    }
    notifyListeners();

    // Sync to backend
    try {
      await _service.savePreferences(clientId, {key: value});
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Save multiple preferences at once (convenience wrapper for calendar screen)
  Future<void> savePreferences(String clientId, Map<String, String?> prefs) async {
    for (final entry in prefs.entries) {
      switch (entry.key) {
        case 'trainer_id': _trainerId = entry.value; break;
        case 'training_type_id': _trainingTypeId = entry.value; break;
        case 'location_id': _locationId = entry.value; break;
      }
    }
    try {
      await _service.savePreferences(clientId, prefs);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Save all preferences at once
  Future<void> saveAll(String clientId) async {
    try {
      await _service.savePreferences(clientId, {
        'trainer_id': _trainerId,
        'training_type_id': _trainingTypeId,
        'location_id': _locationId,
      });
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Clear preferences (e.g. on logout)
  void clear() {
    _trainerId = null;
    _trainingTypeId = null;
    _locationId = null;
    _isLoaded = false;
    _service.clearCache();
    notifyListeners();
  }
}
