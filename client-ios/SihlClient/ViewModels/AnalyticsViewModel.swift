import Foundation

/// Pendant zu `PerformanceProvider` — lädt Leistungsdaten, Metriken und Trainingsreviews.
/// Gibt alle drei Quellen parallel ab (wie Flutter `Future.wait`).
@MainActor @Observable final class AnalyticsViewModel {
    var sections: [PerformanceSection] = []   // Metriken + Tests zusammen
    var reviews:  [TrainingReview]     = []
    var isLoading = false
    var error: String?

    func fetch(clientId: String) async {
        // Demo-Modus: Mock-Daten wie Flutter (`loadMockData` in performance_provider.dart)
        if clientId == "demo" {
            sections = Self.demoSections()
            reviews  = Self.demoReviews()
            isLoading = false
            error = nil
            return
        }
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

    // MARK: - Demo-Daten (Pendant zu Flutter `MockData.performanceData`)

    private static func demoSections() -> [PerformanceSection] {
        [PerformanceSection(json: [
            "section": "Körperwerte",
            "data": [
                ["key": "Gewicht", "value": "78.4", "previousValue": "79.5", "change": "-1.1", "unit": "kg",
                 "history": [
                    ["date": "2026-01-15", "value": "82.0", "unit": "kg"],
                    ["date": "2026-03-10", "value": "81.2", "unit": "kg"],
                    ["date": "2026-05-05", "value": "80.1", "unit": "kg"],
                    ["date": "2026-07-20", "value": "79.5", "unit": "kg"],
                    ["date": "2026-08-08", "value": "78.4", "unit": "kg"],
                 ]],
                ["key": "Körperfett", "value": "14.2", "previousValue": "16.0", "change": "-1.8", "unit": "%",
                 "history": [
                    ["date": "2026-01-15", "value": "18.0", "unit": "%"],
                    ["date": "2026-05-05", "value": "16.0", "unit": "%"],
                    ["date": "2026-08-08", "value": "14.2", "unit": "%"],
                 ]],
            ],
        ])]
    }

    private static func demoReviews() -> [TrainingReview] {
        // HR-Kurve: 120 Punkte, Aufwärmen → Intervalle → Cooldown
        var chart: [[String: Any]] = []
        for i in 0..<120 {
            let base = 105.0 + 55.0 * sin(Double(i) / 120.0 * .pi)
            let interval = i > 30 && i < 100 ? 12.0 * sin(Double(i) / 6.0) : 0
            chart.append([
                "t": String(format: "2026-08-20T18:%02d:00.000Z", i % 60),
                "v": (base + interval).rounded(),
            ])
        }
        return [
            TrainingReview(json: [
                "id": "demo-1", "date": "2026-08-20T18:00:00.000Z",
                "trainingType": "Intervalltraining", "duration": "01:00:00",
                "hrMax": 172, "hrAvg": 141, "chart": chart,
            ]),
            TrainingReview(json: [
                "id": "demo-2", "date": "2026-08-14T07:30:00.000Z",
                "trainingType": "Grundlagenausdauer", "duration": "00:45:00",
                "hrMax": 148, "hrAvg": 126,
                "chart": (0..<90).map { i in
                    ["t": String(format: "2026-08-14T07:%02d:00.000Z", i % 60),
                     "v": (118.0 + 18.0 * sin(Double(i) / 90.0 * .pi)).rounded()]
                },
            ]),
        ]
    }
}
