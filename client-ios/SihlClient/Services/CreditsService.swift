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

    // MARK: - Online-Zahlung (Saferpay)

    /// `POST /api/client/payment/initialize/{clientId}` — Saferpay initialisieren.
    /// Ohne Rechnungsnummer liesse sich der Status nicht abfragen → Fehler.
    func initializePayment(clientId: String, packageId: Int) async throws -> PaymentInitResult {
        let body: [String: Any] = ["packageId": packageId]
        let json = try await APIClient.shared.postJSONObject(
            "/api/client/payment/initialize/\(clientId)", body: body)
        if let d = json, d["success"] as? Bool == true,
           let url = d["redirectUrl"] as? String, !url.isEmpty,
           let invoice = d["invoiceNumber"] as? String, !invoice.isEmpty {
            return PaymentInitResult(redirectUrl: url, invoiceNumber: invoice)
        }
        let msg = json?["error"] as? String ?? "Zahlung konnte nicht gestartet werden"
        throw NSError(domain: "CreditsService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    /// `GET /api/client/payment/status/{invoiceNumber}` — Status abfragen.
    /// Netzwerkfehler werden geworfen; fachliche Fehler kommen als `.failed`.
    func checkPaymentStatus(invoiceNumber: String) async throws -> PaymentStatus {
        guard !invoiceNumber.isEmpty else { return .failed("Rechnung nicht gefunden") }
        guard let d = try await APIClient.shared.getJSONObject(
            "/api/client/payment/status/\(invoiceNumber)") else {
            return .failed("Ungültige Antwort vom Server")
        }
        guard d["success"] as? Bool == true else {
            return .failed(d["error"] as? String ?? "Zahlungsstatus unbekannt")
        }
        switch (d["status"] as? String ?? "pending").lowercased() {
        case "paid":                                     return .paid
        case "failed", "cancelled", "canceled", "aborted": return .failed("Zahlung nicht abgeschlossen")
        default:                                         return .pending
        }
    }
}
