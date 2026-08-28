import Foundation

/// Übungskatalog. Pendant zu den Calls aus `exercise_catalog_sheet.dart`.
struct ExerciseService {

    func exercises() async throws -> [Exercise] {
        let data = try await APIClient.shared.get(APIConfig.exercise)
        return Self.list(from: data).map(Exercise.init(json:))
    }

    func groups() async throws -> [ExerciseGroup] {
        let data = try await APIClient.shared.get(APIConfig.exerciseGroups)
        return Self.list(from: data).map(ExerciseGroup.init(json:))
    }

    private static func list(from data: Data) -> [[String: Any]] {
        let json = try? JSONSerialization.jsonObject(with: data)
        if let array = json as? [[String: Any]] { return array }
        if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            return array
        }
        return []
    }
}
