import Foundation

// MARK: - SubscriptionStatus

/// Pendant zu `models/subscription.dart`.
struct SubscriptionStatus {
    let active:       Bool
    let tier:         String?   // 'trial' | 'monthly' | 'yearly'
    let validFrom:    String?
    let validTo:      String?
    let daysLeft:     Int?
    let isTrial:      Bool
    let trialUsed:    Bool
    let canStartTrial: Bool
    let expiringSoon: Bool

    init(
        active: Bool = false, tier: String? = nil,
        validFrom: String? = nil, validTo: String? = nil, daysLeft: Int? = nil,
        isTrial: Bool = false, trialUsed: Bool = false,
        canStartTrial: Bool = false, expiringSoon: Bool = false
    ) {
        self.active       = active;  self.tier         = tier
        self.validFrom    = validFrom; self.validTo      = validTo
        self.daysLeft     = daysLeft; self.isTrial       = isTrial
        self.trialUsed    = trialUsed; self.canStartTrial = canStartTrial
        self.expiringSoon = expiringSoon
    }

    init(json: [String: Any]) {
        self.active       = json["active"]       as? Bool ?? false
        self.tier         = json["tier"]         as? String
        self.validFrom    = json["validFrom"]     as? String
        self.validTo      = json["validTo"]       as? String
        let raw           = json["daysLeft"]
        self.daysLeft     = (raw as? Int) ?? (raw as? String).flatMap(Int.init)
        self.isTrial      = json["isTrial"]      as? Bool ?? false
        self.trialUsed    = json["trialUsed"]    as? Bool ?? false
        self.canStartTrial = json["canStartTrial"] as? Bool ?? false
        self.expiringSoon = json["expiringSoon"] as? Bool ?? false
    }

    var tierLabel: String {
        switch tier {
        case "trial":   return "Test-Abo"
        case "yearly":  return "Jahres-Abo"
        case "monthly": return "Monats-Abo"
        default:        return "Online Coaching"
        }
    }
}

// MARK: - TrainingPlanRow

/// Eine Übungszeile innerhalb eines Plan-Abschnitts.
/// Pendant zu `TrainingPlanRow` in `models/training_plan.dart`.
struct TrainingPlanRow {
    let exercise: String
    let device:   String
    let position: String   // Coaching-Notiz (lange Texte)
    let weight:   String
    let sets:     String   // z. B. "3×12"
    let dates:    [String] // 8 wöchentliche Spalten
    let timers:   [Int]    // Countdown-Presets (Sekunden)

    init(json: [String: Any]) {
        self.exercise = json["exercise"] as? String ?? ""
        self.device   = json["device"]   as? String ?? ""
        self.position = json["position"] as? String ?? ""
        self.weight   = json["weight"]   as? String ?? ""
        self.sets     = json["sets"]     as? String ?? ""
        self.dates    = (json["dates"] as? [Any])?.map { "\($0)" }
                        ?? Array(repeating: "", count: 8)
        self.timers   = Self.parseTimers(json)
    }

    private static func parseInt(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let s = v as? String { return Int(s) }
        return nil
    }

    private static func parseTimers(_ json: [String: Any]) -> [Int] {
        if let list = json["timers"] as? [Any] {
            return list.compactMap { parseInt($0) }.filter { $0 > 0 }
        }
        if let single = parseInt(json["timer"]), single > 0 { return [single] }
        return []
    }
}

// MARK: - TrainingPlanValues

/// Die vier Abschnitte eines Plans: Aufwärmen, Haupttraining, Core, Mobilität.
/// Pendant zu `TrainingPlanValues` in `models/training_plan.dart`.
struct TrainingPlanValues {
    let sonsomo:  [TrainingPlanRow]
    let main:     [TrainingPlanRow]
    let core:     [TrainingPlanRow]
    let mobility: [TrainingPlanRow]
    let dates:    [String]

    init(json: [String: Any]) {
        func rows(_ key: String) -> [TrainingPlanRow] {
            (json[key] as? [[String: Any]])?.map { TrainingPlanRow(json: $0) } ?? []
        }
        self.sonsomo  = rows("sonsomo")
        self.main     = rows("main")
        self.core     = rows("core")
        self.mobility = rows("mobility")
        self.dates    = (json["dates"] as? [Any])?.map { "\($0)" }
                        ?? Array(repeating: "", count: 8)
    }

    func rows(for key: String) -> [TrainingPlanRow] {
        switch key {
        case "sonsomo":  return sonsomo
        case "main":     return main
        case "core":     return core
        case "mobility": return mobility
        default:         return []
        }
    }
}

// MARK: - ClientTrainingPlan

/// Top-Level Trainingsplan wie er dem Client angezeigt wird.
/// Pendant zu `ClientTrainingPlan` in `models/training_plan.dart`.
struct ClientTrainingPlan: Identifiable, Hashable {
    let id:                 Int?
    let clientId:           Int?
    let name:               String?
    let type:               String?
    let status:             String?
    let publishedAt:        String?
    let locked:             Bool
    let requiresSubscription: Bool
    let sections:           [String: Int]
    let values:             TrainingPlanValues?
    var clientLikes:        [String: String]
    let coverExerciseName:  String?

    var totalExercises: Int { sections.values.reduce(0, +) }

    // Hashable / Equatable via planId
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(json: [String: Any]) {
        // Values: JSON-String oder Dict
        var vals: TrainingPlanValues?
        let raw = json["values"]
        if let str = raw as? String, !str.isEmpty,
           let data = str.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            vals = TrainingPlanValues(json: dict)
        } else if let dict = raw as? [String: Any] {
            vals = TrainingPlanValues(json: dict)
        }
        self.values = vals

        // Sections: aus JSON oder aus Values ableiten
        var sec: [String: Int] = [:]
        if let raw = json["sections"] as? [String: Any] {
            for (k, v) in raw {
                let n = (v as? Int) ?? Int("\(v)") ?? 0
                if n > 0 { sec[k] = n }
            }
        } else if let v = vals {
            if !v.sonsomo.isEmpty  { sec["sonsomo"]  = v.sonsomo.count  }
            if !v.main.isEmpty     { sec["main"]     = v.main.count     }
            if !v.core.isEmpty     { sec["core"]     = v.core.count     }
            if !v.mobility.isEmpty { sec["mobility"] = v.mobility.count }
        }
        self.sections = sec

        func asInt(_ v: Any?) -> Int? {
            (v as? Int) ?? (v as? String).flatMap(Int.init)
        }
        self.id                   = asInt(json["id"])
        self.clientId             = asInt(json["client_id"] ?? json["clientId"])
        self.name                 = json["name"]     as? String
        self.type                 = json["type"]     as? String
        self.status               = json["status"]   as? String
        self.publishedAt          = (json["publishedAt"] ?? json["published_at"]) as? String
        self.locked               = json["locked"]               as? Bool ?? false
        self.requiresSubscription = json["requiresSubscription"] as? Bool ?? false
        self.clientLikes          = (json["clientLikes"] as? [String: Any])?
                                        .mapValues { "\($0)" } ?? [:]
        self.coverExerciseName    = json["coverExerciseName"] as? String
    }
}
