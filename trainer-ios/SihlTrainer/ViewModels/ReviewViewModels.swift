import Foundation

/// Aufzeichnungen eines Kunden.
@MainActor
final class ClientReviewsViewModel: ObservableObject {
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let service = ReviewService()
    private let clientId: Int
    private let isPreview: Bool

    init(clientId: Int, isPreview: Bool) {
        self.clientId = clientId
        self.isPreview = isPreview
    }

    func load() async {
        #if DEBUG
        if isPreview {
            reviews = PreviewData.reviews
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            reviews = try await service.reviews(clientId: clientId)
            error = nil
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Aufzeichnungen konnten nicht geladen werden"
        }
    }
}

/// Eine Aufzeichnung im Detail: Zeitreihe laden, Belastung rechnen.
@MainActor
final class ReviewDetailViewModel: ObservableObject {
    @Published private(set) var points: [HeartRatePoint] = []
    @Published private(set) var isLoading = false

    private let service = ReviewService()
    private let review: Review
    /// Maximalpuls des Kunden — Grundlage für Zonen und Belastung.
    let hrMax: Int
    private let isPreview: Bool

    init(review: Review, hrMax: Int, isPreview: Bool) {
        self.review = review
        self.hrMax = hrMax
        self.isPreview = isPreview
    }

    var trimp: Double? {
        Trimp.edwards(points, hrMax: hrMax, duration: review.duration)
    }

    var maxHeartRate: Double? {
        points.compactMap(\.value).max()
    }

    func load() async {
        #if DEBUG
        if isPreview {
            points = PreviewData.heartRateSeries
            return
        }
        #endif
        isLoading = true
        defer { isLoading = false }
        // Eine fehlende Zeitreihe ist kein Fehler: nicht jede Aufzeichnung
        // hatte einen Brustgurt dabei.
        points = (try? await service.timeseries(reviewId: review.id)) ?? []
    }
}
