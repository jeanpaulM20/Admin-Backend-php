import Foundation
import CryptoKit

/// Pendant zu `trainer-flutter/lib/services/auth_service.dart`.
/// Der Passcode wird nie übertragen — der Token ist md5(salt + passcode) und
/// geht als `X-Auth-Token` an jeden Request.
struct AuthService {

    /// Token aus dem Passcode ableiten (md5, wie im Legacy-PHP-Backend).
    func token(for passcode: String) -> String {
        let digest = Insecure.MD5.hash(data: Data((APIConfig.salt + passcode).utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Login: Token setzen und `GET trainer/me` versuchen. Schlägt der Call
    /// fehl, war der Passcode falsch — der Token wird wieder verworfen.
    func login(passcode: String) async throws -> Trainer {
        let token = token(for: passcode)
        await APIClient.shared.setToken(token)
        do {
            let trainer = try await fetchMe()
            KeychainStore.set(token, for: AuthService.tokenKey)
            return trainer
        } catch {
            await APIClient.shared.setToken(nil)
            throw error
        }
    }

    /// `trainer/me` liefert je nach Backend ein Objekt oder eine Liste mit
    /// einem Element — beide Formen kommen vor (NestJS vs. Legacy-PHP).
    func fetchMe() async throws -> Trainer {
        let data = try await APIClient.shared.get(APIConfig.trainerMe)
        let json = try? JSONSerialization.jsonObject(with: data)
        if let object = json as? [String: Any] {
            return Trainer(json: object)
        }
        if let list = json as? [[String: Any]], let first = list.first {
            return Trainer(json: first)
        }
        throw APIError(statusCode: 401, message: "Anmeldung fehlgeschlagen")
    }

    /// Gespeicherten Token in den APIClient laden. Gibt zurück, ob einer da war.
    @discardableResult
    func restoreToken() async -> Bool {
        guard let token = KeychainStore.get(AuthService.tokenKey), !token.isEmpty else {
            return false
        }
        await APIClient.shared.setToken(token)
        return true
    }

    func logout() async {
        KeychainStore.remove(AuthService.tokenKey)
        await APIClient.shared.setToken(nil)
    }

    static let tokenKey = "auth_token"
}
