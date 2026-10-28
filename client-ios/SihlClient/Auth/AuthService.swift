import Foundation

/// Pendant zu Flutter `auth_service.dart`.
/// Kapselt den Login-Request gegen `POST api/client/token`.
struct AuthService {
    private let api = APIClient.shared

    func login(email: String, password: String) async throws -> AuthToken {
        let data = try await api.post(APIClient.loginPath, body: [
            "email": email,
            "passcode": password,
        ])
        let auth: AuthToken
        do {
            auth = try JSONDecoder().decode(AuthToken.self, from: data)
        } catch {
            throw APIError(statusCode: -2, message: "Anmeldung fehlgeschlagen – unerwartete Serverantwort")
        }
        // Ohne Token oder Kunden-ID wäre die App nicht nutzbar (leere Tabs)
        guard !auth.token.isEmpty, !auth.clientId.isEmpty else {
            throw APIError(statusCode: -2, message: "Anmeldung fehlgeschlagen – bitte später erneut versuchen")
        }
        return auth
    }
}
