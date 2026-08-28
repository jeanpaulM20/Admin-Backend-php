import Foundation

/// Katalogzustand: laden, suchen, filtern.
@MainActor
final class ExerciseCatalogViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var groups: [ExerciseGroup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    @Published var query = ""
    @Published var selectedGroupId: Int?
    @Published var selectedBodyRegion: String?

    private let service = ExerciseService()
    private let isPreview: Bool

    init(isPreview: Bool) {
        self.isPreview = isPreview
    }

    /// Körperregionen kommen aus den Daten selbst — das Backend führt dafür
    /// keine eigene Liste.
    var bodyRegions: [String] {
        Array(Set(exercises.compactMap(\.bodyRegion))).sorted()
    }

    var filtered: [Exercise] {
        exercises.filter { exercise in
            if let selectedBodyRegion, exercise.bodyRegion != selectedBodyRegion { return false }
            if let selectedGroupId, exercise.groupId != selectedGroupId { return false }
            return exercise.matches(query)
        }
    }

    func load() async {
        #if DEBUG
        if isPreview {
            exercises = PreviewData.exercises
            groups = PreviewData.exerciseGroups
            return
        }
        #endif
        guard exercises.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Beide Listen parallel — der Katalog ist ohne Gruppen unvollständig.
            async let exercises = service.exercises()
            async let groups = service.groups()
            self.exercises = try await exercises
            self.groups = try await groups
            error = nil
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Übungen konnten nicht geladen werden"
        }
    }
}
