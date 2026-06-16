import Foundation

/// Auth-Ticket vom LibreLinkUp Login-Endpoint.
struct LibreAuthTicket: Codable {
    let token: String
    let expires: Date

    var isExpired: Bool { Date() > expires }

    private enum CodingKeys: String, CodingKey {
        case token, expires
    }

    init(token: String, expires: Date) {
        self.token = token
        self.expires = expires
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = (try? c.decode(String.self, forKey: .token)) ?? ""
        // `expires` kommt als Unix-Timestamp in Millisekunden
        if let ms = try? c.decode(Int.self, forKey: .expires), ms > 0 {
            expires = Date(timeIntervalSince1970: Double(ms) / 1000)
        } else {
            expires = Date().addingTimeInterval(60 * 60 * 24 * 180)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(token, forKey: .token)
        try c.encode(Int(expires.timeIntervalSince1970 * 1000), forKey: .expires)
    }
}

/// Verbundenes Libre-Profil (Patient oder Follower).
struct LibreConnection: Decodable {
    let patientId: String
    let firstName: String
    let lastName: String
}

/// Region bestimmt den API-Endpunkt — Schweiz → `.eu`.
enum LibreRegion: String, CaseIterable, Codable {
    case eu = "https://api-eu.libreview.io"
    case us = "https://api.libreview.io"
    case de = "https://api-de.libreview.io"
    case ap = "https://api-ap.libreview.io"

    var displayName: String {
        switch self {
        case .eu: return "Europa (EU)"
        case .us: return "USA"
        case .de: return "Deutschland (DE)"
        case .ap: return "Asien/Pazifik (AP)"
        }
    }
}
