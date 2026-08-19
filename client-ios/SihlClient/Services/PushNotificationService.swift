import Foundation
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
///
/// Backend muss APNS_KEY / APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID konfigurieren
/// und das `apn` npm-Paket installieren, um tatsächlich zu senden (siehe push.service.ts).
actor PushNotificationService {
    static let shared = PushNotificationService()
    private init() {}

    private let tokenKey  = "sihl_apns_token"
    private var clientId: String?

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

    /// Permission anfordern und bei Erfolg APNs-Registrierung anstoßen.
    /// - Returns: `true` wenn Permission erteilt.
    @discardableResult
    func requestAndRegister(clientId: String) async -> Bool {
        self.clientId = clientId
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[APNs] requestAuthorization error: \(error)")
            return false
        }
    }

    /// Konfiguriert die clientId (z.B. beim App-Start, nach Login).
    func configure(clientId: String) {
        self.clientId = clientId
        // Falls schon ein Token vorhanden, erneut beim Backend registrieren
        // (z.B. nach App-Neuinstall, Token-Rotation)
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            Task {
                await registerTokenWithBackend(token: token, clientId: clientId)
            }
        }
    }

    /// Aufgerufen von AppDelegate bei erfolgreichem APNs-Handshake.
    func updateDeviceToken(_ data: Data) async {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        guard let id = clientId else { return }
        await registerTokenWithBackend(token: token, clientId: id)
    }

    /// Abmelden: Backend-Subscription löschen + UIKit abmelden.
    func disable(clientId: String) async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        do {
            _ = try await APIClient.shared.post(
                "/api/client/push/\(clientId)/unsubscribe-ios",
                body: ["token": token]
            )
        } catch {
            print("[APNs] unsubscribe error: \(error)")
        }
        UserDefaults.standard.removeObject(forKey: tokenKey)
        await MainActor.run {
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    // MARK: - Private

    private func registerTokenWithBackend(token: String, clientId: String) async {
        do {
            _ = try await APIClient.shared.post(
                "/api/client/push/\(clientId)/subscribe-ios",
                body: ["token": token]
            )
            print("[APNs] Token beim Backend registriert.")
        } catch {
            print("[APNs] Backend-Registrierung fehlgeschlagen: \(error)")
        }
    }
}
