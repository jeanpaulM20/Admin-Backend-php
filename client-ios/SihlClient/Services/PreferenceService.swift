import Foundation

/// Buchungs-Präferenzen (Standard-Trainer, Trainingstyp, Standort).
/// Pendant zu `services/preference_service.dart`.
/// Cached lokal; sync mit Backend bei Änderung.
actor PreferenceService {
    private var cache: [String: String?]?

    func getPreferences(clientId: String) async throws -> [String: String?] {
        if let cached = cache { return cached }

        let data = try await APIClient.shared.get("api/client/preferences/\(clientId)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return emptyPrefs()
        }
        let prefs: [String: String?] = [
            "trainer_id":       json["trainer_id"]       as? String,
            "training_type_id": json["training_type_id"] as? String,
            "location_id":      json["location_id"]      as? String,
        ]
        cache = prefs
        return prefs
    }

    func savePreferences(clientId: String, prefs: [String: String?]) async throws {
        var body: [String: Any] = [:]
        for key in ["trainer_id", "training_type_id", "location_id"] {
            if let val = prefs[key] {
                body[key] = val as Any
            }
        }
        guard !body.isEmpty else { return }
        _ = try await APIClient.shared.put("api/client/preferences/\(clientId)", body: body)
        cache = cache.map { c in
            var updated = c
            for (k, v) in prefs { updated[k] = v }
            return updated
        } ?? prefs
    }

    func clearCache() { cache = nil }

    private func emptyPrefs() -> [String: String?] {
        ["trainer_id": nil, "training_type_id": nil, "location_id": nil]
    }
}
