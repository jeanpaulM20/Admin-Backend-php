import Foundation

/// Trainingsaufzeichnungen eines Kunden.
/// Pendant zu den Review-Calls aus `workout_feedback_screen.dart`.
struct ReviewService {

    func reviews(clientId: Int) async throws -> [Review] {
        let data = try await APIClient.shared.get("\(APIConfig.review)?client_id=\(clientId)")
        let json = try? JSONSerialization.jsonObject(with: data)
        var list: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            list = array
        } else if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            list = array
        }
        // Neueste zuerst — Aufzeichnungen ohne Datum ans Ende.
        return list.map(Review.init(json:))
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Herzfrequenz-Zeitreihe einer Aufzeichnung. Fehlt sie, ist das kein
    /// Fehler — nicht jede Aufzeichnung hat einen Gurt gesehen.
    func timeseries(reviewId: Int) async throws -> [HeartRatePoint] {
        let data = try await APIClient.shared.get("\(APIConfig.review)/\(reviewId)/timeseries")
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.map(HeartRatePoint.init(json:)).sorted { $0.sort < $1.sort }
    }
}
