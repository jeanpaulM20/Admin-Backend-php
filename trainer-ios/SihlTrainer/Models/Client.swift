import Foundation

/// Pendant zu `models/client.dart`.
struct Client: Identifiable, Equatable {
    let id: Int
    let clientCode: String?
    let name: String
    let email: String?
    let phone: String?
    let photo: String?
    let address: String?
    let dateOfBirth: String?
    let notes: String?
    let memberSince: String?
    let trainerId: Int?
    let trainingType: String?
    let locationName: String?
    let minHeartRate: Int?
    let maxHeartRate: Int?
    let autoTrainingNotify: Bool

    init(json: [String: Any]) {
        id = JSON.int(json, "id", "client_id") ?? 0
        clientCode = JSON.string(json, "clientid", "client_id_code")
        name = Client.buildName(json)
        // Entity-Property "email", Legacy-PHP-Spalte "e_mail".
        email = JSON.string(json, "email", "e_mail")
        phone = JSON.string(json, "phone", "mobile", "telephone")
        photo = JSON.string(json, "photo", "picture", "image", "avatar", "foto")
        address = Client.buildAddress(json)
        dateOfBirth = JSON.string(json, "date_of_birth", "birthday", "dob")
        notes = JSON.string(json, "notes", "comment")
        memberSince = JSON.string(json, "member_since", "created_at", "registration_date")
        trainerId = JSON.intNonZero(json, "trainer_id", "trainerId")
        trainingType = JSON.string(json, "training_type", "type")
        locationName = JSON.string(json, "location_name", "location")
        minHeartRate = JSON.intNonZero(json, "min_heart_rate", "minHeartRate")
        maxHeartRate = JSON.intNonZero(json, "max_heart_rate", "maxHeartRate")
        autoTrainingNotify = JSON.bool(json, "auto_training_notify", "autoTrainingNotify")
    }

    /// `name` kann der volle Name sein oder nur der Vorname — dann steht der
    /// Nachname in surname/last_name/lastname.
    private static func buildName(_ json: [String: Any]) -> String {
        if let first = JSON.string(json, "name") {
            if let surname = JSON.string(json, "surname", "last_name", "lastname") {
                return "\(first) \(surname)"
            }
            return first
        }
        let first = JSON.string(json, "first_name", "firstname") ?? ""
        let last = JSON.string(json, "last_name", "lastname", "surname") ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Unbekannter Kunde" : full
    }

    private static func buildAddress(_ json: [String: Any]) -> String? {
        if let address = JSON.string(json, "address") { return address }
        // Das Backend führt keinen Strassennamen: nur zip + domicile (Ort).
        let parts = [
            JSON.string(json, "street"),
            JSON.string(json, "zip", "postal_code"),
            JSON.string(json, "city", "domicile"),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var initials: String { name.initials }

    /// Suchtreffer über Name, E-Mail und Telefon — wie der Filter in
    /// `clients_screen.dart`.
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let needle = query.lowercased()
        if name.lowercased().contains(needle) { return true }
        if let email, email.lowercased().contains(needle) { return true }
        if let phone, phone.contains(query) { return true }
        return false
    }
}
