import Foundation

// MARK: - Anfrage

/// Steuerung der KI-Plangenerierung — Pendant zu `AiPlanRequest` im Backend.
struct AiPlanRequest {
    enum Modality: String, CaseIterable, Identifiable {
        case athletik, fitness
        case reformer = "pilates_reformer"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .athletik: return "Athletik"
            case .fitness:  return "Fitness"
            case .reformer: return "Reformer"
            }
        }
    }

    /// Repertoire-Level für Reformer-Pläne — Pendant zu `REFORMER_LEVELS`.
    enum ReformerLevel: String, CaseIterable, Identifiable {
        case beginner, intermediate, advanced
        var id: String { rawValue }
        var title: String {
            switch self {
            case .beginner:     return "Basic"
            case .intermediate: return "Intermediate"
            case .advanced:     return "Advanced"
            }
        }
    }

    enum TrainingType: String, CaseIterable, Identifiable {
        case ausdauer, kraft, propriozeptiv, mental_health, athletik, schnelligkeit
        var id: String { rawValue }
        var title: String {
            switch self {
            case .ausdauer:      return "Ausdauer"
            case .kraft:         return "Kraft"
            case .propriozeptiv: return "Propriozeptiv"
            case .mental_health: return "Mental"
            case .athletik:      return "Athletik"
            case .schnelligkeit: return "Schnelligkeit"
            }
        }
    }

    enum AusdauerIntensity: String, CaseIterable, Identifiable {
        case regenerativ, allgemeine, spezial, schwelle, hiit
        var id: String { rawValue }
        var title: String {
            switch self {
            case .regenerativ: return "Regenerativ (Z1)"
            case .allgemeine:  return "Grundlage (Z2)"
            case .spezial:     return "Tempo (Z3)"
            case .schwelle:    return "Schwelle (Z4)"
            case .hiit:        return "HIIT (Z5)"
            }
        }
    }

    enum StrengthGoal: String, CaseIterable, Identifiable {
        case maxkraft, hypertrophie, kraftausdauer
        var id: String { rawValue }
        var title: String {
            switch self {
            case .maxkraft:      return "Maximalkraft · 3–5×3–6"
            case .hypertrophie:  return "Hypertrophie · 3–4×8–12"
            case .kraftausdauer: return "Kraftausdauer · 2–3×15–25"
            }
        }
    }

    enum Equipment: String, CaseIterable, Identifiable {
        case mft, slackline, springseil, kettlebell, ringe
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mft:        return "MFT Board"
            case .slackline:  return "Slackline"
            case .springseil: return "Springseil"
            case .kettlebell: return "Kettlebell"
            case .ringe:      return "Ringe"
            }
        }
    }

    var modality: Modality = .athletik
    var trainingType: TrainingType = .kraft
    var duration: Int? = 45
    var equipment: Set<Equipment> = []
    var ausdauerIntensity: AusdauerIntensity = .allgemeine
    var strengthGoal: StrengthGoal = .hypertrophie
    var level: ReformerLevel = .beginner

    /// Body wie ihn `validatePlanRequest` im Backend erwartet.
    var body: [String: Any] {
        // Reformer: Trainingstyp und Geräte sind im Repertoire festgelegt —
        // das Backend verlangt den Typ trotzdem, ignoriert ihn aber.
        if modality == .reformer {
            return [
                "trainingType": TrainingType.kraft.rawValue,
                "duration": duration as Any,
                "equipment": NSNull(),
                "modality": modality.rawValue,
                "level": level.rawValue,
            ]
        }
        var result: [String: Any] = [
            "trainingType": trainingType.rawValue,
            "duration": duration as Any,
            "equipment": equipment.isEmpty ? NSNull() : equipment.map(\.rawValue).sorted(),
            "modality": modality.rawValue,
        ]
        if trainingType == .ausdauer { result["ausdauerIntensity"] = ausdauerIntensity.rawValue }
        if modality == .fitness { result["strengthGoal"] = strengthGoal.rawValue }
        return result
    }
}

// MARK: - Ergebnis

/// Was `ai/generate` zurückgibt: der gespeicherte Plan plus die Begründung.
struct AiPlanOutcome {
    let plan: TrainingPlan
    let reasoning: String
    let isRuleBased: Bool
    let contraindications: [String]
    let excluded: [(name: String, reason: String)]
    let weaknesses: [String]

    init(json: [String: Any]) {
        plan = TrainingPlan(json: json["plan"] as? [String: Any] ?? [:])
        let meta = json["meta"] as? [String: Any] ?? [:]
        reasoning = JSON.string(meta, "ai_reasoning") ?? ""
        isRuleBased = JSON.bool(meta, "isRuleBased")
        contraindications = (meta["contraindications"] as? [String]) ?? []
        excluded = ((meta["excludedByContraindication"] as? [[String: Any]]) ?? []).compactMap { item in
            guard let name = JSON.string(item, "name") else { return nil }
            return (name: name, reason: JSON.string(item, "reason") ?? "")
        }
        weaknesses = ((meta["weaknesses"] as? [[String: Any]]) ?? []).compactMap { JSON.string($0, "label") }
    }
}

struct AiPlanService {
    /// Generiert und speichert den Plan in einem Schritt.
    /// Der LLM-Aufruf dauert 30–60 s — darum das lange Zeitlimit.
    func generate(clientId: Int, request: AiPlanRequest) async throws -> AiPlanOutcome {
        let data = try await APIClient.shared.post(
            "\(APIConfig.trainingPlan)/ai/generate/\(clientId)",
            body: request.body,
            timeout: 120
        )
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Unerwartete Antwort")
        }
        return AiPlanOutcome(json: json)
    }
}
