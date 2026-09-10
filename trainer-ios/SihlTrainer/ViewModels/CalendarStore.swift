import Foundation

/// Verfügbarkeiten für den Kalender. Die Termine kommen aus dem
/// `TrainerStore` — beide werden im Tagesdetail zusammengeführt.
@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var slotsByDay: [Date: [AvailabilitySlot]] = [:]
    /// Belegte Zeiten aus abonnierten Fremdkalendern (Phase 2).
    @Published private(set) var externalBusy: [ExternalBusy] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let service = AvailabilityService()
    private let feeds = CalendarFeedService()

    func load(trainerId: Int) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let slots = try await service.slots(trainerId: trainerId)
            slotsByDay = Dictionary(grouping: slots.filter { $0.day != nil }) { $0.day! }
            // Fremdkalender separat: ein Fehler dort darf die Verfügbarkeit
            // nicht mitreissen — die Abos sind eine Zusatzquelle.
            let from = Calendar.sihl.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let to = Calendar.sihl.date(byAdding: .day, value: 90, to: Date()) ?? Date()
            externalBusy = (try? await feeds.busy(trainerId: trainerId, from: from, to: to)) ?? []
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Verfügbarkeit konnte nicht geladen werden"
        }
    }

    /// Fremdtermine eines Tages, aufsteigend.
    func externalBusy(on day: Date) -> [ExternalBusy] {
        externalBusy
            .filter { Calendar.sihl.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// Tage mit mindestens einem Fremdtermin — für die Markierung im Raster.
    var externalBusyDays: Set<Date> {
        Set(externalBusy.map { Calendar.sihl.startOfDay(for: $0.start) })
    }

    func slots(on day: Date) -> [AvailabilitySlot] {
        let key = Calendar.current.startOfDay(for: day)
        return (slotsByDay[key] ?? []).sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }

    #if DEBUG
    func loadPreviewData() {
        let slots = PreviewData.availability
        slotsByDay = Dictionary(grouping: slots.filter { $0.day != nil }) { $0.day! }
        externalBusy = PreviewData.externalBusy
        error = nil
    }
    #endif
}
