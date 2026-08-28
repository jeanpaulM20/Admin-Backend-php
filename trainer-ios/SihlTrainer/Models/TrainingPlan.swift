import Foundation

/// Eine Übungszeile im Trainingsplan.
/// Pendant zu `TrainingPlanRow` aus `models/training_plan.dart`.
///
/// `id` ist rein lokal (SwiftUI braucht eine stabile Identität beim
/// Bearbeiten) und wird nicht ans Backend geschickt.
struct TrainingPlanRow: Identifiable, Equatable {
    let id = UUID()
    var exercise = ""
    var device = ""
    var position = ""
    var weight = ""
    var sets = ""            // z.B. "3×12"
    var comment = ""
    var liked = false
    var disliked = false
    var timers: [Int] = []   // gespeicherte Timer-Vorgaben in Sekunden

    init() {}

    init(json: [String: Any]) {
        exercise = JSON.string(json, "exercise") ?? ""
        device = JSON.string(json, "device") ?? ""
        position = JSON.string(json, "position") ?? ""
        weight = JSON.string(json, "weight") ?? ""
        sets = JSON.string(json, "sets") ?? ""
        comment = JSON.string(json, "comment") ?? ""
        liked = JSON.bool(json, "liked")
        disliked = JSON.bool(json, "disliked")
        timers = TrainingPlanRow.parseTimers(json)
    }

    /// Neues Format: `timers` als Liste. Altes Format: ein einzelnes `timer`.
    private static func parseTimers(_ json: [String: Any]) -> [Int] {
        if let list = json["timers"] as? [Any] {
            return list.compactMap { value in
                if let number = value as? Int { return number > 0 ? number : nil }
                if let text = value as? String, let number = Int(text) { return number > 0 ? number : nil }
                return nil
            }
        }
        if let single = JSON.int(json, "timer"), single > 0 { return [single] }
        return []
    }

    /// Nur gesetzte Felder senden — wie `toJson()` in Dart.
    var json: [String: Any] {
        var result: [String: Any] = [
            "exercise": exercise,
            "device": device,
            "position": position,
            "weight": weight,
        ]
        if !sets.isEmpty { result["sets"] = sets }
        if liked { result["liked"] = true }
        if disliked { result["disliked"] = true }
        if !timers.isEmpty { result["timers"] = timers }
        if !comment.isEmpty { result["comment"] = comment }
        return result
    }

    var isEmpty: Bool {
        exercise.isEmpty && device.isEmpty && position.isEmpty && weight.isEmpty && sets.isEmpty
    }
}

/// Die vier Abschnitte eines Plans.
enum PlanSection: String, CaseIterable, Identifiable {
    case sonsomo, main, core, mobility

    var id: String { rawValue }

    /// Anzeigenamen wie in `training_plan_detail_screen.dart`.
    var title: String {
        switch self {
        case .sonsomo:  return "AUFWÄRMEN"
        case .main:     return "HAUPTTRAINING"
        case .core:     return "CORE"
        case .mobility: return "MOBILITÄT"
        }
    }

    var icon: String {
        switch self {
        case .sonsomo:  return "figure.cooldown"
        case .main:     return "dumbbell"
        case .core:     return "figure.core.training"
        case .mobility: return "figure.flexibility"
        }
    }
}

/// Inhalt eines Plans: vier Abschnitte plus acht Termin-Spalten.
struct TrainingPlanValues: Equatable {
    var sections: [PlanSection: [TrainingPlanRow]]
    var dates: [String]

    init() {
        sections = Dictionary(uniqueKeysWithValues: PlanSection.allCases.map { ($0, []) })
        dates = Array(repeating: "", count: 8)
    }

    init(json: [String: Any]) {
        self.init()
        for section in PlanSection.allCases {
            let list = json[section.rawValue] as? [[String: Any]] ?? []
            sections[section] = list.map(TrainingPlanRow.init(json:))
        }
        if let raw = json["dates"] as? [Any] {
            var parsed = raw.map { String(describing: $0 is NSNull ? "" : $0) }
            while parsed.count < 8 { parsed.append("") }
            dates = Array(parsed.prefix(8))
        }
    }

    var json: [String: Any] {
        var result: [String: Any] = ["dates": dates]
        for section in PlanSection.allCases {
            result[section.rawValue] = (sections[section] ?? []).map(\.json)
        }
        return result
    }

    var totalRows: Int {
        PlanSection.allCases.reduce(0) { $0 + (sections[$1]?.count ?? 0) }
    }

    subscript(section: PlanSection) -> [TrainingPlanRow] {
        get { sections[section] ?? [] }
        set { sections[section] = newValue }
    }
}

/// Ein Trainingsplan. Pendant zu `TrainingPlan` aus `models/training_plan.dart`.
struct TrainingPlan: Identifiable, Equatable {
    var id: Int?
    var clientId: Int?
    var name: String?
    var values: TrainingPlanValues
    var createdAt: String?
    /// 'draft' = Trainer bearbeitet noch, 'published' = für den Kunden freigegeben.
    var status: String?
    var publishedAt: String?

    var isPublished: Bool { status == "published" }

    init(clientId: Int?, name: String? = nil) {
        self.clientId = clientId
        self.name = name
        values = TrainingPlanValues()
        status = "draft"
    }

    init(json: [String: Any]) {
        id = JSON.int(json, "id")
        clientId = JSON.int(json, "client_id", "clientId")
        name = JSON.string(json, "name")
        createdAt = JSON.string(json, "created_at", "createdAt")
        status = JSON.string(json, "status")
        publishedAt = JSON.string(json, "publishedAt", "published_at")

        // `values` kommt je nach Backend als JSON-String oder als Objekt.
        if let text = json["values"] as? String, !text.isEmpty,
           let data = text.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            values = TrainingPlanValues(json: decoded)
        } else if let object = json["values"] as? [String: Any] {
            values = TrainingPlanValues(json: object)
        } else {
            values = TrainingPlanValues()
        }
    }

    /// Speicher-Payload. `values` geht als JSON-String raus — so erwartet es
    /// das Backend (Legacy-Spalte).
    var savePayload: [String: Any] {
        var result: [String: Any] = [:]
        if let id { result["id"] = id }
        if let clientId { result["client_id"] = clientId }
        if let name { result["name"] = name }
        if let data = try? JSONSerialization.data(withJSONObject: values.json),
           let text = String(data: data, encoding: .utf8) {
            result["values"] = text
        }
        return result
    }
}
