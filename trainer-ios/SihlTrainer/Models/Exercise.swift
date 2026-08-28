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

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        name = JSON.string(json, "name") ?? ""
        groupId = JSON.intNonZero(json, "group_id", "groupId")
        group = (json["group"] as? [String: Any]).map(ExerciseGroup.init(json:))
        subgroupName = (json["subgroup"] as? [String: Any]).flatMap { JSON.string($0, "name") }
        bodyRegion = JSON.string(json, "body_region", "bodyRegion")
        primaryMuscleGroup = JSON.string(json, "primary_muscle_group", "primaryMuscleGroup")
        movementPattern = JSON.string(json, "movement_pattern", "movementPattern")
    }

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
