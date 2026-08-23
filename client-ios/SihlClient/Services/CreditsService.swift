import Foundation

/// Pendant zu `credits_service.dart` + `payment_service.dart`.
struct CreditsService {
    static let shared = CreditsService()
    private init() {}

    // MARK: - Credits & Packages

    /// `GET /api/client/credits/{clientId}`
    func listClientCredits(clientId: String) async throws -> [ClientCredit] {
        try await APIClient.shared
            .getJSONArray("/api/client/credits/\(clientId)")
            .map { ClientCredit(json: $0) }
    }

    /// `GET /api/client/packages` + `GET /api/client/packages?kind=coaching` (parallel)
    func listPackages() async throws -> [CreditPackage] {
        async let credits  = APIClient.shared.getJSONArray("/api/client/packages")
        async let coaching = APIClient.shared.getJSONArray("/api/client/packages?kind=coaching")
        let (c, co) = try await (credits, coaching)
        return (c + co).map { CreditPackage(json: $0) }
    }

    /// `GET /api/client/packages?kind=coaching` — nur Coaching-Abos (für Paywall)
    func listCoachingPackages() async throws -> [CreditPackage] {
        try await APIClient.shared
            .getJSONArray("/api/client/packages?kind=coaching")
            .map { CreditPackage(json: $0) }
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

    // MARK: - Online Payment (Saferpay)

    /// `POST /api/client/payment/initialize/{clientId}` — Saferpay initialisieren
    func initializePayment(clientId: String, packageId: Int) async throws -> PaymentInitResult {
        let body: [String: Any] = ["packageId": packageId]
        let json = try await APIClient.shared.postJSONObject(
            "/api/client/payment/initialize/\(clientId)", body: body)
        if let d = json, d["success"] as? Bool == true,
           let url = d["redirectUrl"] as? String {
            return PaymentInitResult(
                redirectUrl: url,
                invoiceNumber: d["invoiceNumber"] as? String ?? ""
            )
        }
        let msg = json?["error"] as? String ?? "Zahlung konnte nicht gestartet werden"
        throw NSError(domain: "CreditsService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    /// `GET /api/client/payment/status/{invoiceNumber}` — Status abfragen
    func checkPaymentStatus(invoiceNumber: String) async throws -> String {
        guard let d = try await APIClient.shared.getJSONObject(
            "/api/client/payment/status/\(invoiceNumber)"),
              d["success"] as? Bool == true else { return "error" }
        return d["status"] as? String ?? "pending"
    }
}
