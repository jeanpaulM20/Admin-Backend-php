import Foundation

/// Pendant zu `models/training_type.dart`.
struct TrainingType: Identifiable {
    let id: String
    let name: String
    let duration: Int      // Sekunden

    var durationMinutes: Int { duration / 60 }

    init(json: [String: Any]) {
        self.id       = "\(json["id"] ?? "")"
        self.name     = (json["name"] as? String) ?? ""
        self.duration = Int("\(json["duration"] ?? 3600)") ?? 3600
    }
}
