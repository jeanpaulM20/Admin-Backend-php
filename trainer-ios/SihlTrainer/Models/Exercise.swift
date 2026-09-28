import Foundation

/// Übungsgruppe (im Plan zugleich die Geräteangabe).
struct ExerciseGroup: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        name = JSON.string(json, "name") ?? ""
    }
}

/// Eine Übung aus dem Katalog. Pendant zu `models/exercise.dart`.
struct Exercise: Identifiable, Equatable {
    let id: Int
    let name: String
    let groupId: Int?
    let group: ExerciseGroup?
    let subgroupName: String?
    let bodyRegion: String?
    let primaryMuscleGroup: String?
    let movementPattern: String?
    // Etappe 6: Felder aus dem erweiterten Katalog
    let modality: String?
    let level: String?
    let equipment: String?
    let instructionsDe: String?
    let cuesDe: String?

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        name = JSON.string(json, "name") ?? ""
        groupId = JSON.intNonZero(json, "group_id", "groupId")
        group = (json["group"] as? [String: Any]).map(ExerciseGroup.init(json:))
        subgroupName = (json["subgroup"] as? [String: Any]).flatMap { JSON.string($0, "name") }
        bodyRegion = JSON.string(json, "body_region", "bodyRegion")
        primaryMuscleGroup = JSON.string(json, "primary_muscle_group", "primaryMuscleGroup")
        movementPattern = JSON.string(json, "movement_pattern", "movementPattern")
        modality = JSON.string(json, "modality")
        level = JSON.string(json, "level")
        equipment = JSON.string(json, "equipment")
        instructionsDe = JSON.string(json, "instructions_de", "instructionsDe")
        cuesDe = JSON.string(json, "cues_de", "cuesDe")
    }

    var levelTitle: String? {
        switch level {
        case "beginner": return "Einsteiger"
        case "intermediate": return "Mittel"
        case "advanced": return "Fortgeschritten"
        default: return nil
        }
    }

    /// Deutsches Geräte-Label; unbekannte Schlüssel werden lesbar gemacht
    /// (`smith_machine` → „Smith machine") statt verschluckt.
    var equipmentTitle: String? {
        guard let key = equipment?.trimmingCharacters(in: .whitespaces), !key.isEmpty else { return nil }
        if let known = Exercise.equipmentLabels[key] { return known }
        return key.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }

    /// Schlüssel des RepDB-Vokabulars (und `reformer` aus dem eigenen Blatt).
    static let equipmentLabels: [String: String] = [
        "barbell": "Langhantel",
        "dumbbell": "Kurzhantel",
        "kettlebell": "Kettlebell",
        "ez_bar": "SZ-Stange",
        "trap_bar": "Trap Bar",
        "plates": "Hantelscheiben",
        "cable": "Kabelzug",
        "smith_machine": "Multipresse",
        "pull_up_bar": "Klimmzugstange",
        "dip_station": "Dip-Barren",
        "rings": "Ringe",
        "suspension_trainer": "Schlingentrainer",
        "loop_band": "Miniband",
        "resistance_band": "Widerstandsband",
        "flat_bench": "Flachbank",
        "stability_ball": "Gymnastikball",
        "slam_ball": "Slam Ball",
        "ab_wheel": "Bauchroller",
        "wrist_roller": "Unterarmroller",
        "plyo_box": "Sprungkasten",
        "jump_rope": "Springseil",
        "battle_rope": "Battle Rope",
        "climbing_rope": "Klettertau",
        "sled": "Schlitten",
        "glute_ham_developer": "Glute-Ham-Developer",
        "leg_press": "Beinpresse",
        "hack_squat": "Hackenschmidt-Maschine",
        "leg_curl": "Beinbeuger",
        "leg_extension": "Beinstrecker",
        "hip_thrust_machine": "Hip-Thrust-Maschine",
        "hip_abduction_machine": "Abduktoren-Maschine",
        "hip_adduction_machine": "Adduktoren-Maschine",
        "standing_calf_raise_machine": "Wadenmaschine stehend",
        "seated_calf_raise_machine": "Wadenmaschine sitzend",
        "donkey_calf_raise_machine": "Donkey-Wadenmaschine",
        "back_extension_machine": "Rückenstrecker-Maschine",
        "ab_crunch_machine": "Bauchmaschine",
        "lat_pulldown_machine": "Latzug",
        "assisted_pullup_machine": "Klimmzug-Hilfsmaschine",
        "chest_press_machine": "Brustpresse",
        "chest_fly_machine": "Butterfly",
        "pec_deck": "Butterfly",
        "shoulder_press_machine": "Schulterpresse",
        "plate_loaded_lateral_raise_machine": "Seitheben-Maschine",
        "shrug_machine": "Shrug-Maschine",
        "bicep_curl_machine": "Bizeps-Maschine",
        "preacher_curl_machine": "Scott-Curl-Pult",
        "tricep_extension_machine": "Trizeps-Maschine",
        "dip_machine": "Dip-Maschine",
        "treadmill": "Laufband",
        "rower": "Rudergerät",
        "stationary_bike": "Ergometer",
        "air_bike": "Air Bike",
        "elliptical": "Crosstrainer",
        "stair_climber": "Stepper",
        "reformer": "Reformer",
    ]

    /// Symbolbild der Übung. Liefert das Backend keines, zeigt die Zeile ein
    /// Platzhaltersymbol.
    var iconURL: URL? {
        URL(string: "exercise/\(id)/icon.png", relativeTo: APIConfig.baseURL)
    }

    /// Suchtreffer über Name, Gruppe, Untergruppe und Muskelgruppe — wie der
    /// Filter in `exercise_catalog_sheet.dart`.
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = query.lowercased()
        if name.lowercased().contains(needle) { return true }
        if let group, group.name.lowercased().contains(needle) { return true }
        if let subgroupName, subgroupName.lowercased().contains(needle) { return true }
        if let primaryMuscleGroup, primaryMuscleGroup.lowercased().contains(needle) { return true }
        return false
    }
}

/// Was die Auswahl an die Planzeile zurückgibt: Name und Gerät (= Gruppe).
struct ExerciseSelection {
    let name: String
    let device: String
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
