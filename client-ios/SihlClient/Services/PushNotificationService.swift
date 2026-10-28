import Foundation
import OSLog
import UIKit
import UserNotifications

/// Pendant zu `push_notification_service.dart` — iOS-native APNs statt Web Push.
///
/// Ablauf:
///  1. `requestAndRegister(clientId:)` → Permission-Dialog → APNs-Registrierung
///  2. `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` →
///     `updateDeviceToken(_:)` → `POST /api/client/push/{clientId}/subscribe-ios`
///  3. `disable(clientId:)` → `POST /api/client/push/{clientId}/unsubscribe-ios` +
///     `UIApplication.unregisterForRemoteNotifications()`
///  4. `configure(clientId:)` bei jedem Start/Login: bei erteilter Berechtigung
///     erneut registrieren, damit ein rotiertes Token beim Backend ankommt.
///  5. `logoutCleanup(clientId:)` beim Logout (vor dem Löschen des Tokens).
///
/// Backend muss APNS_KEY / APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID konfigurieren
/// und das `apn` npm-Paket installieren, um tatsächlich zu senden (siehe push.service.ts).
actor PushNotificationService {
    static let shared = PushNotificationService()
    private init() {}

    private let tokenKey  = "sihl_apns_token"
    /// Nutzer hat Push im Profil ausgeschaltet → beim Start nicht wieder
    /// registrieren. Je Konto gespeichert und beim Abmelden NICHT gelöscht,
    /// sonst wäre Push nach erneutem Anmelden ungefragt wieder an.
    private func optOutKey(_ clientId: String) -> String { "sihl_push_opt_out_\(clientId)" }
    private var clientId: String?

    private static let log = Logger(subsystem: "ch.sihltraining.SihlClient", category: "APNs")

    // MARK: - Public API

    /// Aktuellen Authorisierungsstatus prüfen (ohne Dialog)
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// True, wenn Benachrichtigungen aktiv und ein Token registriert ist.
    var isEnabled: Bool {
        get async {
            let status = await authorizationStatus()
            let hasToken = UserDefaults.standard.string(forKey: tokenKey) != nil
            return (status == .authorized || status == .provisional) && hasToken
        }
    }

    /// Permission anfordern und bei Erfolg APNs-Registrierung anstossen.
    /// - Returns: `true` wenn Permission erteilt.
    @discardableResult
    func requestAndRegister(clientId: String) async -> Bool {
        self.clientId = clientId
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UserDefaults.standard.removeObject(forKey: optOutKey(clientId))
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            Self.log.error("requestAuthorization: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    /// Konfiguriert die clientId (beim App-Start und nach Login). Bei erteilter
    /// Berechtigung jedes Mal neu bei APNs registrieren — das Token kann
    /// rotieren; `updateDeviceToken` meldet es dann dem Backend.
    func configure(clientId: String) async {
        self.clientId = clientId
        guard !UserDefaults.standard.bool(forKey: optOutKey(clientId)) else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }
        // Bekanntes Token sofort melden (z. B. nach Kontowechsel), das
        // frische folgt über `updateDeviceToken`
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            await registerTokenWithBackend(token: token, clientId: clientId)
        }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Aufgerufen von AppDelegate bei erfolgreichem APNs-Handshake.
    func updateDeviceToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        let previous = UserDefaults.standard.string(forKey: tokenKey)
        UserDefaults.standard.set(token, forKey: tokenKey)
        guard let id = clientId else { return }
        // Unverändertes Token hat `configure` schon gemeldet
        if previous == token { return }
        await registerTokenWithBackend(token: token, clientId: id)
    }

    /// Vom Nutzer ausgeschaltet: Backend-Subscription löschen + UIKit abmelden.
    func disable(clientId: String) async {
        UserDefaults.standard.set(true, forKey: optOutKey(clientId))
        await unsubscribe(clientId: clientId)
    }

    /// Logout: beim Backend abmelden (solange das Token noch gilt), lokales
    /// Token und Einstellungen verwerfen, clientId zurücksetzen.
    func logoutCleanup(clientId: String?) async {
        if let clientId, !clientId.isEmpty, clientId != AuthViewModel.demoClientId {
            await unsubscribe(clientId: clientId)
        } else {
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        self.clientId = nil
    }

    // MARK: - Private

    private func unsubscribe(clientId: String) async {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            do {
                _ = try await APIClient.shared.post(
                    "/api/client/push/\(clientId)/unsubscribe-ios",
                    body: ["token": token],
                    timeout: 8
                )
            } catch {
                Self.log.error("Abmelden fehlgeschlagen: \(error.localizedDescription, privacy: .private)")
            }
        }
        UserDefaults.standard.removeObject(forKey: tokenKey)
        await MainActor.run {
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    private func registerTokenWithBackend(token: String, clientId: String) async {
        do {
            _ = try await APIClient.shared.post(
                "/api/client/push/\(clientId)/subscribe-ios",
                body: ["token": token]
            )
            #if DEBUG
            Self.log.debug("Token beim Backend registriert.")
            #endif
        } catch {
            Self.log.error("Backend-Registrierung fehlgeschlagen: \(error.localizedDescription, privacy: .private)")
        }
    }
}
