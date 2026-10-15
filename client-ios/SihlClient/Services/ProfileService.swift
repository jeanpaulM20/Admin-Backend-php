import Foundation

/// Pendant zu `services/profile_service.dart` + Polar-Calls aus `screens/profile_screen.dart`.
struct ProfileService {

    // MARK: - Profil & Rechnungen & Dateien

    func getProfile(clientId: String) async throws -> ProfileData {
        let data = try await APIClient.shared.get("api/client/profile/\(clientId)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Ungültige Profildaten")
        }
        return ProfileData(json: json)
    }

    /// Roh-Profil (Gewicht, BMI, Körperfett, Ruhepuls) für das Metrik-Sheet
    /// im Chat — die Felder werden dort dynamisch eingeblendet.
    func getProfileMetrics(clientId: String) async throws -> [String: Any] {
        guard let json = try await APIClient.shared.getJSONObject("api/client/profile/\(clientId)") else {
            throw APIError(statusCode: 500, message: "Ungültige Profildaten")
        }
        return json
    }

    func getInvoices(clientId: String) async throws -> [Invoice] {
        let data = try await APIClient.shared.get("api/client/invoices/\(clientId)")
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.map { Invoice(json: $0) }
    }

    func getFiles(clientId: String) async throws -> [ClientFile] {
        let data = try await APIClient.shared.get("api/client/files/\(clientId)")
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.map { ClientFile(json: $0) }
    }

    // MARK: - Polar

    /// `platform=ios`: Nach der Polar-Anmeldung leitet das Backend auf
    /// `sihlmove://polar` zurück — dort fängt `PolarAuthSession` ab.
    func getPolarStatus(clientId: String) async throws -> PolarStatus {
        guard let json = try await APIClient.shared.getJSONObject(
            "api/client/polar/status/\(clientId)?platform=ios") else {
            return PolarStatus(available: false, connected: false, connectUrl: nil, lastSyncAt: nil)
        }
        return PolarStatus(json: json)
    }

    /// Liefert die Meldung des Servers, z. B. „3 Polar-Trainings importiert".
    /// Grosszügiges Timeout: Ein Sync holt bis zu 25 Trainings samt HF-Kurve.
    func syncPolar(clientId: String) async throws -> String {
        let json = try await APIClient.shared.postJSONObject(
            "api/client/polar/sync/\(clientId)", body: [:], timeout: 120)
        return (json?["message"] as? String) ?? "Polar-Trainings synchronisiert"
    }

    func disconnectPolar(clientId: String) async throws {
        _ = try await APIClient.shared.post("api/client/polar/disconnect/\(clientId)", body: [:])
    }
}
