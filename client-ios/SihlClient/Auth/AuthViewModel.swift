import Foundation
import Observation

/// Pendant zu Flutter `auth_provider.dart` (ChangeNotifier → @Observable).
///
/// Hält Auth-Zustand, persistiert Token in der Keychain und die clientId
/// in UserDefaults (nicht sensibel). Wird per `.environment(...)` injiziert
/// und mit `@Environment(AuthViewModel.self)` in Views gelesen.
@MainActor
@Observable
final class AuthViewModel {
    private let service = AuthService()
    private let api = APIClient.shared

    private enum Keys {
        static let token = "auth_token"      // Keychain
        static let clientId = "client_id"    // UserDefaults
    }

    nonisolated static let demoClientId = "demo"

    private(set) var token: String?
    private(set) var clientId: String?
    var isLoading = false
    /// Meldung für den Login-Screen (falsches Passwort, Sitzung abgelaufen …)
    var error: String?

    /// Verhindert doppelte Abmeldung (mehrere parallele 401).
    private(set) var isLoggingOut = false

    var isAuthenticated: Bool { (token?.isEmpty == false) }
    var isDemo: Bool { clientId == Self.demoClientId }

    init() {
        // Synchron lesen (Keychain ist schnell): kein kurzes Aufblitzen des
        // Login-Screens beim Kaltstart.
        token = KeychainStore.get(Keys.token)
        clientId = UserDefaults.standard.string(forKey: Keys.clientId)
        guard let token, !token.isEmpty else { return }
        api.setToken(token)
        // clientId aus alter Session evtl. nicht gespeichert → vom Server holen.
        if clientId?.isEmpty != false {
            Task { await recoverMissingClientId() }
        }
    }

    // MARK: - Persistenz

    private func recoverMissingClientId() async {
        await recoverClientId()
        // Ohne clientId ist die App nicht nutzbar (RootView gated darauf) —
        // dann lieber sauber ausloggen statt endlos im Ladezustand hängen.
        if isAuthenticated, clientId?.isEmpty != false {
            await logout()
        }
    }

    private func recoverClientId() async {
        guard let obj = try? await api.getJSONObject("api/client/me") else { return }
        let id = (obj["id"] as? String) ?? (obj["id"] as? Int).map(String.init)
        if let id, !id.isEmpty {
            clientId = id
            UserDefaults.standard.set(id, forKey: Keys.clientId)
        }
    }

    private func saveAuth() {
        KeychainStore.set(token, for: Keys.token)
        if let clientId, !clientId.isEmpty {
            UserDefaults.standard.set(clientId, forKey: Keys.clientId)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.clientId)
        }
    }

    // MARK: - Aktionen

    @discardableResult
    func login(email: String, password: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            let auth = try await service.login(email: email, password: password)
            token = auth.token
            clientId = auth.clientId
            api.setToken(auth.token)
            saveAuth()
            isLoading = false
            return true
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Demo/Preview-Login (mirror von `loginDemo`).
    func loginDemo() {
        error = nil
        token = "demo-token-preview"
        clientId = Self.demoClientId
    }

    /// Abmelden inkl. zentraler Aufräum-Routine (`SessionCleanup`).
    func logout() async {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }

        // Push-Abmeldung braucht noch das gültige Token
        await SessionCleanup.beforeTokenRemoval(clientId: clientId)

        token = nil
        clientId = nil
        api.setToken(nil)
        saveAuth()

        await SessionCleanup.afterTokenRemoval()
    }

    /// Vom APIClient bei 401 ausgelöst: abmelden und Hinweis zeigen.
    func sessionExpired() async {
        guard isAuthenticated, !isDemo, !isLoggingOut else { return }
        await logout()
        error = "Sitzung abgelaufen – bitte neu anmelden"
    }

    func clearError() { error = nil }
}
