import Foundation

/// Datenzugriff für Kunden und Termine.
/// Pendant zu den Fetch-Methoden aus `providers/trainer_provider.dart`.
struct TrainerDataService {

    /// `GET client` — Antwort ist entweder ein Array oder `{ data: [...] }`.
    func clients() async throws -> [Client] {
        let data = try await APIClient.shared.get(APIConfig.client)
        return Self.list(from: data).map(Client.init(json:))
    }

    /// `GET training?trainer_id=…` — Datumsfilter nur senden, wenn gesetzt:
    /// Auswertungen brauchen den ungefilterten Bestand.
    func trainings(trainerId: Int, from: Date? = nil, to: Date? = nil) async throws -> [Training] {
        var path = "\(APIConfig.training)?trainer_id=\(trainerId)"
        if let from { path += "&date_from=\(Self.dayFormatter.string(from: from))" }
        if let to { path += "&date_to=\(Self.dayFormatter.string(from: to))" }
        let data = try await APIClient.shared.get(path)
        return Self.list(from: data).map(Training.init(json:))
    }

    /// Beide Antwortformen des Backends auf eine Liste bringen.
    private static func list(from data: Data) -> [[String: Any]] {
        let json = try? JSONSerialization.jsonObject(with: data)
        if let array = json as? [[String: Any]] { return array }
        if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            return array
        }
        return []
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
