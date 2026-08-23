import Foundation

/// Pendant zu `PerformanceProvider` — lädt Leistungsdaten, Metriken und Trainingsreviews.
/// Gibt alle drei Quellen parallel ab (wie Flutter `Future.wait`).
@MainActor @Observable final class AnalyticsViewModel {
    var sections: [PerformanceSection] = []   // Metriken + Tests zusammen
    var reviews:  [TrainingReview]     = []
    var isLoading = false
    var error: String?

    func fetch(clientId: String) async {
        isLoading = true
        error     = nil
        do {
            async let tests   = PerformanceService.shared.getPerformanceData(clientId: clientId)
            async let metrics = PerformanceService.shared.getMetrics(clientId: clientId)
            async let revs    = PerformanceService.shared.getReviews(clientId: clientId)

            let (t, m, r) = try await (tests, metrics, revs)
            // Metriken zuerst, dann Tests — wie Flutter `[...metrics, ...tests]`
            sections = m + t
            reviews  = r
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
