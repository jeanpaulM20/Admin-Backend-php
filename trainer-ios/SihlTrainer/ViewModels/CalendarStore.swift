import Foundation

/// Verfügbarkeiten für den Kalender. Die Termine kommen aus dem
/// `TrainerStore` — beide werden im Tagesdetail zusammengeführt.
@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var slotsByDay: [Date: [AvailabilitySlot]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let service = AvailabilityService()

    func load(trainerId: Int) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let slots = try await service.slots(trainerId: trainerId)
            slotsByDay = Dictionary(grouping: slots.filter { $0.day != nil }) { $0.day! }
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Verfügbarkeit konnte nicht geladen werden"
        }
    }

    func slots(on day: Date) -> [AvailabilitySlot] {
        let key = Calendar.current.startOfDay(for: day)
        return (slotsByDay[key] ?? []).sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }

    #if DEBUG
    func loadPreviewData() {
        let slots = PreviewData.availability
        slotsByDay = Dictionary(grouping: slots.filter { $0.day != nil }) { $0.day! }
        error = nil
    }
    #endif
}
