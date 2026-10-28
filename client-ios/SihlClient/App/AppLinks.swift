import Foundation

/// Zentrale externe Adressen (Datenschutz, Kontakt).
enum AppLinks {
    /// Datenschutzerklärung für Kundinnen und Kunden
    static let privacy = URL(string: "https://admin-backend-php-production.up.railway.app/legal/datenschutz.html")!

    /// Kontakt für Konto, Zugang und Löschanfragen
    static let supportEmail = "hello@sihltraining.ch"

    /// mailto-Link an den Support, optional mit Betreff und Text.
    static func supportMail(subject: String? = nil, body: String? = nil) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = supportEmail
        var items: [URLQueryItem] = []
        if let subject { items.append(URLQueryItem(name: "subject", value: subject)) }
        if let body { items.append(URLQueryItem(name: "body", value: body)) }
        c.queryItems = items.isEmpty ? nil : items
        return c.url
    }
}
