import Foundation

/// Pendant zu `models/trainer.dart`.
struct Trainer: Identifiable, Equatable {
    let id: Int
    let name: String
    let email: String?
    let phone: String?
    let photo: String?
    let description: String?

    init(json: [String: Any]) {
        id = JSON.int(json, "id", "trainer_id") ?? 0
        // NestJS liefert firstname/lastname getrennt, PHP ein fertiges name.
        if let full = JSON.string(json, "name", "trainer_name") {
            name = full
        } else {
            let first = JSON.string(json, "firstname", "first_name") ?? ""
            let last = JSON.string(json, "lastname", "last_name") ?? ""
            name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        }
        email = JSON.string(json, "email")
        phone = JSON.string(json, "phone", "mobile")
        // NestJS "picture", PHP "photo"/"image"
        photo = JSON.string(json, "photo", "image", "picture")
        description = JSON.string(json, "description", "about")
    }

    var initials: String { name.initials }
}
