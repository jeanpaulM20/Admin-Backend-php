import Foundation

/// Pendant zu `credits_service.dart` + `payment_service.dart`.
struct CreditsService {
    static let shared = CreditsService()
    private init() {}

    // MARK: - Credits & Packages

    /// `GET /api/client/credits/{clientId}`
    func listClientCredits(clientId: String) async throws -> [ClientCredit] {
        let json = try await APIClient.shared.get("/api/client/credits/\(clientId)")
        return (json as? [[String: Any]] ?? []).map { ClientCredit(json: $0) }
    }

    /// `GET /api/client/packages` + `GET /api/client/packages?kind=coaching` (parallel)
    func listPackages() async throws -> [CreditPackage] {
        async let credits  = APIClient.shared.get("/api/client/packages")
        async let coaching = APIClient.shared.get("/api/client/packages?kind=coaching")
        let (c, co) = try await (credits, coaching)
        let combined = (c as? [[String: Any]] ?? []) + (co as? [[String: Any]] ?? [])
        return combined.map { CreditPackage(json: $0) }
    }

    /// `POST /api/client/purchase/{clientId}` — Banküberweisung / QR-Rechnung
    func purchasePackage(clientId: String, packageId: String) async throws -> (success: Bool, message: String) {
        let body: [String: Any] = ["packageId": Int(packageId) ?? 0]
        let json = try await APIClient.shared.post("/api/client/purchase/\(clientId)", body: body)
        if let d = json as? [String: Any] {
            return (d["success"] as? Bool ?? false,
                    d["message"] as? String ?? "Unbekannter Fehler")
        }
        return (false, "Unbekannter Fehler")
    }

    // MARK: - Online Payment (Saferpay)

    /// `POST /api/client/payment/initialize/{clientId}` — Saferpay initialisieren
    func initializePayment(clientId: String, packageId: Int) async throws -> PaymentInitResult {
        let body: [String: Any] = ["packageId": packageId]
        let json = try await APIClient.shared.post(
            "/api/client/payment/initialize/\(clientId)", body: body)
        if let d = json as? [String: Any], d["success"] as? Bool == true,
           let url = d["redirectUrl"] as? String {
            return PaymentInitResult(
                redirectUrl: url,
                invoiceNumber: d["invoiceNumber"] as? String ?? ""
            )
        }
        let msg = (json as? [String: Any])?["error"] as? String ?? "Zahlung konnte nicht gestartet werden"
        throw NSError(domain: "CreditsService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    /// `GET /api/client/payment/status/{invoiceNumber}` — Status abfragen
    func checkPaymentStatus(invoiceNumber: String) async throws -> String {
        let json = try await APIClient.shared.get("/api/client/payment/status/\(invoiceNumber)")
        if let d = json as? [String: Any], d["success"] as? Bool == true {
            return d["status"] as? String ?? "pending"
        }
        return "error"
    }
}
