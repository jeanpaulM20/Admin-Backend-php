import Foundation

/// Pendant zu Flutter `auth_token.dart`.
/// Server liefert: `{ "token": "...", "client": { "id": 123, "firstname": "...", "lastname": "..." } }`
/// `id` kann als Zahl ODER String kommen — daher der flexible Decoder unten.
struct AuthToken: Decodable {
    let token: String
    let clientId: String
    let firstName: String?
    let lastName: String?

    private enum RootKeys: String, CodingKey {
        case token, client
    }
    private enum ClientKeys: String, CodingKey {
        case id, firstname, lastname
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        token = (try? root.decode(String.self, forKey: .token)) ?? ""

        if let client = try? root.nestedContainer(keyedBy: ClientKeys.self, forKey: .client) {
            clientId = AuthToken.flexibleString(client, .id) ?? ""
            firstName = try? client.decode(String.self, forKey: .firstname)
            lastName = try? client.decode(String.self, forKey: .lastname)
        } else {
            clientId = ""
            firstName = nil
            lastName = nil
        }
    }

    /// Liest einen Wert, egal ob er als String oder Int kodiert ist.
    private static func flexibleString(_ c: KeyedDecodingContainer<ClientKeys>, _ key: ClientKeys) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let i = try? c.decode(Int.self, forKey: key) { return String(i) }
        return nil
    }
}
