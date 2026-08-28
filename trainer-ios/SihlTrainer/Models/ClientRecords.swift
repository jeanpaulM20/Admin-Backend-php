import Foundation

/// Datei im Kundendossier. Pendant zu `models/file_item.dart`.
struct ClientFile: Identifiable, Equatable {
    let id: Int
    let name: String
    let path: String?
    let date: String?

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        name = JSON.string(json, "name", "filename", "file") ?? "Datei"
        path = JSON.string(json, "file", "url", "path")
        date = JSON.string(json, "date", "uploaded_at", "created_at")
    }

    /// Download-Link. Relative Pfade zeigen auf das Backend; der Token hängt
    /// als Query-Parameter dran, weil der Aufruf ausserhalb des APIClient
    /// im Browser landet.
    func downloadURL(token: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api/", with: "")
        let separator = path.contains("?") ? "&" : "?"
        let suffix = token.map { "\(separator)token=\($0)" } ?? ""
        return URL(string: "\(base)\(path.hasPrefix("/") ? "" : "/")\(path)\(suffix)")
    }
}

/// Messwerte eines Kunden. Pendant zu `Metric` aus `models/performance.dart`.
struct MetricEntry: Identifiable, Equatable {
    let id: Int
    let recordedAt: Date?
    let weight: Double?
    let systolic: Double?
    let diastolic: Double?
    let restingPulse: Double?
    let bodyFatKg: Double?
    let bodyFatPercent: Double?
    let waist: Double?
    let bcm: Double?

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        recordedAt = JSON.date(JSON.string(json, "recorded_at", "date", "created_at"))
        weight = JSON.double(json, "weight")
        systolic = JSON.double(json, "sys")
        diastolic = JSON.double(json, "dia")
        restingPulse = JSON.double(json, "calm_pulse", "calmPulse")
        bodyFatKg = JSON.double(json, "body_fat_kg", "bodyFatKg")
        bodyFatPercent = JSON.double(json, "body_fat_perc", "bodyFatPerc")
        waist = JSON.double(json, "waist_circumference", "waistCircumference")
        bcm = JSON.double(json, "bcm")
    }

    /// Nur gesetzte Werte, in der Reihenfolge des Flutter-Screens.
    var values: [(String, String)] {
        var result: [(String, String)] = []
        func add(_ label: String, _ value: Double?, _ unit: String, digits: Int = 1) {
            guard let value, value > 0 else { return }
            result.append((label, String(format: "%.\(digits)f %@", value, unit)))
        }
        add("Gewicht", weight, "kg")
        add("Körperfett", bodyFatPercent, "%")
        add("Körperfett", bodyFatKg, "kg")
        add("Taillenumfang", waist, "cm")
        add("Ruhepuls", restingPulse, "bpm", digits: 0)
        if let systolic, let diastolic, systolic > 0, diastolic > 0 {
            result.append(("Blutdruck", "\(Int(systolic))/\(Int(diastolic))"))
        }
        add("BCM", bcm, "kg")
        return result
    }
}

/// Leistungstest. Pendant zu `Performance` aus `models/performance.dart` —
/// hier auf die Anzeige reduziert.
struct PerformanceTest: Identifiable, Equatable {
    let id: Int
    let recordedAt: Date?
    let points: Double?
    /// Einzelwerte als (Bezeichnung, Wert) in Gruppen.
    let groups: [(title: String, values: [(String, Double)])]

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        recordedAt = JSON.date(JSON.string(json, "recorded_at", "date", "created_at"))
        points = JSON.double(json, "points")

        func collect(_ title: String, _ fields: [(String, String)]) -> (String, [(String, Double)])? {
            let values = fields.compactMap { label, key -> (String, Double)? in
                guard let value = JSON.double(json, key, key.camelCased), value > 0 else { return nil }
                return (label, value)
            }
            return values.isEmpty ? nil : (title, values)
        }

        groups = [
            collect("Beweglichkeit", [
                ("Ischiocrurale", "hamstrings"), ("Waden", "calfs"), ("Adduktoren", "adductors"),
            ]),
            collect("Kraft", [
                ("Klimmzüge", "pullups"), ("Liegestütze", "pushups"),
                ("Rumpfbeugen", "trunk_bending"), ("Unterarmstütz", "forearm_support"),
                ("Seitstütz", "side_support"), ("Wandsitzen", "squat_on_wall"),
            ]),
            collect("Koordination", [
                ("Sensomotorik", "sensomotoric"), ("Symmetrie", "symmetry"),
                ("Reaktion", "reaction"), ("Sprungkraft", "counter_movement_jump"),
                ("Tapping", "tapping"),
            ]),
            collect("Schnelligkeit", [
                ("10 m", "sprint10"), ("20 m", "sprint20"), ("30 m", "sprint30"),
            ]),
        ].compactMap { $0 }.map { (title: $0.0, values: $0.1) }
    }

    static func == (lhs: PerformanceTest, rhs: PerformanceTest) -> Bool { lhs.id == rhs.id }
}

private extension String {
    /// "trunk_bending" → "trunkBending" — das Backend liefert beide Schreibweisen.
    var camelCased: String {
        let parts = split(separator: "_")
        guard let first = parts.first else { return self }
        return String(first) + parts.dropFirst().map { $0.capitalized }.joined()
    }
}

/// Anamnesebogen — hier zur Anzeige, das Ausfüllen bleibt der Client-App und
/// dem Web-Formular überlassen.
struct Anamnese: Equatable {
    let address: String?
    let profession: String?
    let activities: Int?
    let sports: String?
    let sportsScope: String?
    let sleepWeek: Int?
    let sleepWeekend: Int?
    let goals: String?
    let comments: String?
    let injury: Bool
    let injuryType: String?
    let injuryBodypart: String?
    let musculoskeletalProblems: Bool
    let musculoskeletalDescription: String?
    let medicalTreatment: Bool
    let takingDrugs: Bool
    /// Vorerkrankungen, die im Bogen angekreuzt sind.
    let diseases: [String]

    init(json: [String: Any]) {
        address = JSON.string(json, "address")
        profession = JSON.string(json, "profession")
        activities = JSON.int(json, "activities")
        sports = JSON.string(json, "sportarts")
        sportsScope = JSON.string(json, "sportarts_scope", "sportartsScope")
        sleepWeek = JSON.intNonZero(json, "sleep_week", "sleepWeek")
        sleepWeekend = JSON.intNonZero(json, "sleep_weekend", "sleepWeekend")
        goals = JSON.string(json, "goals")
        comments = JSON.string(json, "comments")
        injury = JSON.bool(json, "injury")
        injuryType = JSON.string(json, "injury_type", "injuryType")
        injuryBodypart = JSON.string(json, "injury_bodypart", "injuryBodypart")
        musculoskeletalProblems = JSON.bool(json, "musculoskeletal_problems", "musculoskeletalProblems")
        musculoskeletalDescription = JSON.string(json, "musculoskeletal_problems_description",
                                                 "musculoskeletalProblemsDescription")
        medicalTreatment = JSON.bool(json, "medical_treatment", "medicalTreatment")
        takingDrugs = JSON.bool(json, "taking_drugs", "takingDrugs")

        let catalogue: [(String, String)] = [
            ("Herzinfarkt", "disease_heartattack"),
            ("Arterielle Störung", "disease_arterial_disorder"),
            ("Raynaud-Syndrom", "disease_raynald_syndrome"),
            ("Vaskulitis", "disease_vasculitis"),
            ("Kälteempfindlichkeit", "disease_cold_sensitivity"),
            ("Sensibilitätsstörungen", "disease_sensory_disturbances"),
            ("Durchblutungsstörung", "disease_circulatory_disorder"),
            ("Nervenschädigung", "disease_nerve_damage"),
            ("Replantation", "disease_replantation"),
            ("Lymphatische Erkrankung", "disease_peripheral_lymphatics"),
            ("Hämoglobinämie", "disease_hemoglobinemia"),
            ("Niere/Blase", "disease_kidney_bladder"),
            ("Herz-Kreislauf", "disease_heart_circulatory"),
        ]
        diseases = catalogue.compactMap { label, key in
            JSON.bool(json, key) ? label : nil
        }
    }

    /// Belastung im Alltag — die Zahl ist ein PHP-Enum.
    var activityLabel: String? {
        switch activities {
        case 0: return "Sitzend"
        case 1: return "Mässig"
        case 2: return "Intensiv"
        default: return nil
        }
    }
}
