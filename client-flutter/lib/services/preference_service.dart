import 'api_client.dart';

/// Booking preferences — default trainer, training type, location.
/// Stored in backend `preference` table, cached locally per session.
class PreferenceService {
  Map<String, String?>? _cache;

  /// Load preferences from backend (or cache)
  Future<Map<String, String?>> getPreferences(String clientId) async {
    if (_cache != null) return Map.from(_cache!);

    final data = await apiClient.get('api/client/preferences/$clientId');
    if (data is Map<String, dynamic>) {
      _cache = {
        'trainer_id': data['trainer_id']?.toString(),
        'training_type_id': data['training_type_id']?.toString(),
        'location_id': data['location_id']?.toString(),
      };
      return Map.from(_cache!);
    }
    return {'trainer_id': null, 'training_type_id': null, 'location_id': null};
  }

  /// Save preferences to backend (partial update)
  Future<void> savePreferences(
    String clientId,
    Map<String, String?> prefs,
  ) async {
    final body = <String, dynamic>{};
    for (final key in ['trainer_id', 'training_type_id', 'location_id']) {
      if (prefs.containsKey(key)) {
        body[key] = prefs[key];
      }
    }
    if (body.isEmpty) return;

    await apiClient.put('api/client/preferences/$clientId', body: body);

    // Update cache
    _cache ??= {'trainer_id': null, 'training_type_id': null, 'location_id': null};
    for (final entry in prefs.entries) {
      _cache![entry.key] = entry.value;
    }
  }

  /// Clear cache (e.g. on logout)
  void clearCache() {
    _cache = null;
  }
}
