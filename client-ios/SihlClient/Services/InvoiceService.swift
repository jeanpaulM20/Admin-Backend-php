import Foundation

/// Pendant zu `services/invoice_service.dart`.
struct InvoiceService {

    /// Fetcht das Schweizer QR-Zahlungsschein-PNG (base64-codiert) vom Server.
    /// Gibt die dekodierten Bild-Bytes zurück oder `nil` wenn nicht verfügbar.
    func fetchQrBill(invoiceNumber: String) async throws -> Data? {
        let raw = try await APIClient.shared.get("api/client/invoice-qr/\(invoiceNumber)")
        guard
            let json   = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            json["success"] as? Bool == true,
            let base64 = json["base64"] as? String,
            let decoded = Data(base64Encoded: base64)
        else { return nil }
        return decoded
    }
}
