import Foundation

/// Lektionen-Guthaben & -Pakete für Personal Training vor Ort.
/// Pendant zu `credits_service.dart` + `payment_service.dart`.
/// Online-Coaching-Abos werden in der App bewusst nicht verkauft (App-Store 3.1.1).
struct CreditsService {
    static let shared = CreditsService()
    private init() {}

    // MARK: - Guthaben & Pakete

    /// `GET /api/client/credits/{clientId}`
    func listClientCredits(clientId: String) async throws -> [ClientCredit] {
        try await APIClient.shared
            .getJSONArray("/api/client/credits/\(clientId)")
            .map { ClientCredit(json: $0) }
    }

    /// `GET /api/client/packages` — Lektionen-Pakete (Backend-Default `kind=credits`).
    /// Coaching-Pakete werden zusätzlich clientseitig ausgefiltert.
    func listPackages() async throws -> [CreditPackage] {
        try await APIClient.shared
            .getJSONArray("/api/client/packages")
            .map { CreditPackage(json: $0) }
            .filter { !$0.isCoaching }
    }

    /// `POST /api/client/purchase/{clientId}` — Banküberweisung / QR-Rechnung
    func purchasePackage(clientId: String, packageId: String) async throws -> (success: Bool, message: String) {
        let body: [String: Any] = ["packageId": Int(packageId) ?? 0]
        guard let d = try await APIClient.shared.postJSONObject(
            "/api/client/purchase/\(clientId)", body: body) else {
            return (false, "Unbekannter Fehler")
        }
        return (d["success"] as? Bool ?? false,
                d["message"] as? String ?? "Unbekannter Fehler")
    }
}
