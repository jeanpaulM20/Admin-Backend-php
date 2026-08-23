import Foundation

/// Pendant zu `models/trainer.dart`.
struct Trainer: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let shortName: String
    let picture: String?
    let color: String?

    var fullName: String { "\(firstName) \(lastName)" }

    init(json: [String: Any]) {
        let first = (json["firstname"] as? String) ?? ""
        let last  = (json["lastname"]  as? String) ?? ""
        self.id        = "\(json["id"] ?? "")"
        self.firstName = first
        self.lastName  = last
        self.shortName = (json["shortName"] as? String)
                      ?? "\(first.first.map(String.init) ?? "")\(last.first.map(String.init) ?? "")"
        self.picture   = json["picture"] as? String
        self.color     = json["color"]   as? String
    }
}
