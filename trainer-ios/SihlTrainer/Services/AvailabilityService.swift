import Foundation

/// Verfügbarkeiten des Trainers.
/// Pendant zu `fetchAvailability` aus `providers/trainer_provider.dart`.
struct AvailabilityService {

    /// Ohne `locationId` werden alle Standorte geliefert — die Verfügbarkeit
    /// eines Trainers gilt global, nicht pro Standort.
    func slots(trainerId: Int, locationId: Int = 0) async throws -> [AvailabilitySlot] {
        var path = "\(APIConfig.availability)?trainer_id=\(trainerId)"
        if locationId > 0 { path += "&location_id=\(locationId)" }
        let data = try await APIClient.shared.get(path)
        let json = try? JSONSerialization.jsonObject(with: data)
        var list: [[String: Any]] = []
        if let array = json as? [[String: Any]] {
            list = array
        } else if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            list = array
        }
        return list.map(AvailabilitySlot.init(json:))
    }
}
