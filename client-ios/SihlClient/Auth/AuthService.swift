import Foundation

/// Pendant zu Flutter `auth_service.dart`.
/// Kapselt den Login-Request gegen `POST api/client/token`.
struct AuthService {
    private let api = APIClient.shared

    func login(email: String, password: String) async throws -> AuthToken {
        let data = try await api.post("api/client/token", body: [
            "email": email,
            "passcode": password,
        ])
        do {
            return try JSONDecoder().decode(AuthToken.self, from: data)
        } catch {
            throw APIError(statusCode: 401, message: "Login fehlgeschlagen")
        }
    }
}
