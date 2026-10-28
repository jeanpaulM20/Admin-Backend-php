import AuthenticationServices
import UIKit

/// Status der Polar-Verbindung, wie `GET api/client/polar/status` ihn liefert.
struct PolarStatus {
    /// false = Polar ist auf dem Server nicht eingerichtet
    let available: Bool
    let connected: Bool
    let connectUrl: String?
    let lastSyncAt: Date?

    init(available: Bool, connected: Bool, connectUrl: String?, lastSyncAt: Date?) {
        self.available  = available
        self.connected  = connected
        self.connectUrl = connectUrl
        self.lastSyncAt = lastSyncAt
    }

    init(json: [String: Any]) {
        // Ältere Server kennen `available` nicht — dann wie bisher annehmen
        available  = (json["available"] as? Bool) ?? true
        connected  = json["connected"] as? Bool == true
        connectUrl = json["connectUrl"] as? String
        lastSyncAt = (json["lastSyncAt"] as? String).flatMap(Self.parseDate)
    }

    private static func parseDate(_ s: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}

/// Polar-Anmeldung im sicheren In-App-Browser. Das Backend leitet nach der
/// Anmeldung auf `sihlmove://polar?status=connected|error&message=…` um;
/// `ASWebAuthenticationSession` fängt das ab — ohne registriertes URL-Schema.
@MainActor
final class PolarAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {

    enum Outcome {
        case connected
        case cancelled
        case failed(String)
    }

    static let callbackScheme = "sihlmove"

    private var session: ASWebAuthenticationSession?

    func start(url: URL) async -> Outcome {
        await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(returning: .cancelled)
                } else if let callbackURL {
                    continuation.resume(returning: Self.outcome(from: callbackURL))
                } else {
                    continuation.resume(returning: .failed("Polar-Anmeldung fehlgeschlagen"))
                }
            }
            session.presentationContextProvider = self
            // Eigene, flüchtige Browser-Sitzung: keine Safari-Cookies teilen
            // oder hinterlassen (kein Fremdkonto, kein Hinweisdialog)
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            if !session.start() {
                continuation.resume(returning: .failed("Polar-Anmeldung konnte nicht geöffnet werden"))
            }
        }
    }

    private static func outcome(from url: URL) -> Outcome {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        if value("status") == "connected" { return .connected }
        return .failed(value("message") ?? "Polar-Verbindung fehlgeschlagen")
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
