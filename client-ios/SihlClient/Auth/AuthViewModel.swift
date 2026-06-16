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

    private(set) var token: String?
    private(set) var clientId: String?
    var isLoading = false
    var error: String?

    var isAuthenticated: Bool { (token?.isEmpty == false) }

    init() {
        Task { await loadSavedAuth() }
    }

    // MARK: - Persistenz

    private func loadSavedAuth() async {
        token = KeychainStore.get(Keys.token)
        clientId = UserDefaults.standard.string(forKey: Keys.clientId)
        guard let token, !token.isEmpty else { return }
        await api.setToken(token)
        // clientId aus alter Session evtl. nicht gespeichert → vom Server holen.
        if clientId?.isEmpty != false {
            await recoverClientId()
        }
    }

    private func recoverClientId() async {
        guard let data = try? await api.get("api/client/me"),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
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
            await api.setToken(auth.token)
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
        token = "demo-token-preview"
        clientId = "demo"
    }

    func logout() async {
        token = nil
        clientId = nil
        await api.setToken(nil)
        saveAuth()
    }

    func clearError() { error = nil }
}
