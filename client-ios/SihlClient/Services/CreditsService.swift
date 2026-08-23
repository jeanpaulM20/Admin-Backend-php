import Foundation

/// Pendant zu `credits_service.dart` + `payment_service.dart`.
struct CreditsService {
    static let shared = CreditsService()
    private init() {}

    // MARK: - Credits & Packages

    /// `GET /api/client/credits/{clientId}`
    func listClientCredits(clientId: String) async throws -> [ClientCredit] {
        let data = try await APIClient.shared.get("/api/client/credits/\(clientId)")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { ClientCredit(json: $0) }
    }

    /// `GET /api/client/packages` + `GET /api/client/packages?kind=coaching` (parallel)
    func listPackages() async throws -> [CreditPackage] {
        async let credits  = APIClient.shared.get("/api/client/packages")
        async let coaching = APIClient.shared.get("/api/client/packages?kind=coaching")
        let (c, co) = try await (credits, coaching)
        let cArr  = (try? JSONSerialization.jsonObject(with: c)  as? [[String: Any]]) ?? []
        let coArr = (try? JSONSerialization.jsonObject(with: co) as? [[String: Any]]) ?? []
        return (cArr + coArr).map { CreditPackage(json: $0) }
    }

    /// `GET /api/client/packages?kind=coaching` — nur Coaching-Abos (für Paywall)
    func listCoachingPackages() async throws -> [CreditPackage] {
        let data = try await APIClient.shared.get("/api/client/packages?kind=coaching")
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map { CreditPackage(json: $0) }
    }

    /// `POST /api/client/purchase/{clientId}` — Banküberweisung / QR-Rechnung
    func purchasePackage(clientId: String, packageId: String) async throws -> (success: Bool, message: String) {
        let body: [String: Any] = ["packageId": Int(packageId) ?? 0]
        let data = try await APIClient.shared.post("/api/client/purchase/\(clientId)", body: body)
        if let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (d["success"] as? Bool ?? false,
                    d["message"] as? String ?? "Unbekannter Fehler")
        }
        return (false, "Unbekannter Fehler")
    }

    // MARK: - Online Payment (Saferpay)

    /// `POST /api/client/payment/initialize/{clientId}` — Saferpay initialisieren
    func initializePayment(clientId: String, packageId: Int) async throws -> PaymentInitResult {
        let body: [String: Any] = ["packageId": packageId]
        let data = try await APIClient.shared.post(
            "/api/client/payment/initialize/\(clientId)", body: body)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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
        let data = try await APIClient.shared.get("/api/client/payment/status/\(invoiceNumber)")
        if let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any], d["success"] as? Bool == true {
            return d["status"] as? String ?? "pending"
        }
        return "error"
    }
}
