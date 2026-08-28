import Foundation

/// Anmeldezustand der App. Pendant zu `providers/auth_provider.dart`.
@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var trainer: Trainer?
    @Published private(set) var isLoading = false
    @Published private(set) var isRestoring = true
    @Published var error: String?

    private let service = AuthService()

    var isLoggedIn: Bool { trainer != nil }

    /// Beim Start: Token aus der Keychain holen und gegen `trainer/me` prüfen.
    /// Ein abgelaufener oder geänderter Passcode führt zurück zum Login.
    func restoreSession() async {
        isRestoring = true
        defer { isRestoring = false }
        guard await service.restoreToken() else { return }
        do {
            trainer = try await service.fetchMe()
        } catch {
            await service.logout()
            trainer = nil
        }
    }

    func login(passcode: String) async {
        let trimmed = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Bitte Passcode eingeben"
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            trainer = try await service.login(passcode: trimmed)
        } catch let apiError as APIError {
            self.error = apiError.message
        } catch {
            self.error = "Anmeldung fehlgeschlagen"
        }
    }

    func logout() async {
        await service.logout()
        trainer = nil
        error = nil
        #if DEBUG
        isPreview = false
        #endif
    }

    #if DEBUG
    /// Vorschaumodus: meldet einen Beispiel-Trainer an, ohne Backend und ohne
    /// Passcode. Existiert nur in Debug-Builds.
    @Published private(set) var isPreview = false

    func startPreview() {
        isPreview = true
        trainer = PreviewData.trainer
        error = nil
        isRestoring = false
    }
    #endif
}
