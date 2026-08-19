import Foundation

/// Pendant zu `models/profile_data.dart`.
struct ProfileData {
    let firstName: String
    let lastName: String
    let imageUrl: String?
    let email: String?
    let phone: String?
    let birthday: String?
    let gender: String?
    let creditPacks: [CreditPack]

    /// "Nachname Vorname" — wie im Flutter-Original.
    var fullName: String { "\(lastName) \(firstName)".trimmingCharacters(in: .whitespaces) }

    /// Initialen: Anfangsbuchstaben von Nachname + Vorname (Grossbuchstaben).
    var initials: String {
        let l = lastName.first.map(String.init) ?? ""
        let f = firstName.first.map(String.init) ?? ""
        return (l + f).uppercased()
    }

    init(json: [String: Any]) {
        self.firstName = (json["firstname"] as? String) ?? (json["firstName"] as? String) ?? ""
        self.lastName  = (json["lastname"]  as? String) ?? (json["lastName"]  as? String) ?? ""
        self.imageUrl  = (json["photo"] as? String)
                      ?? (json["picture"] as? String)
                      ?? (json["foto"] as? String)
                      ?? (json["imageUrl"] as? String)
        self.email    = json["email"]    as? String
        self.phone    = json["phone"]    as? String
        self.birthday = json["birthday"] as? String
        self.gender   = json["gender"]   as? String

        let raw = json["creditPacks"] ?? json["credit_packs"]
        if let list = raw as? [[String: Any]] {
            self.creditPacks = list.map { CreditPack(json: $0) }
        } else {
            self.creditPacks = []
        }
    }
}
