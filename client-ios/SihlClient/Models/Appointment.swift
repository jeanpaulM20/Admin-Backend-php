import Foundation

/// Pendant zu `models/appointment.dart`.
struct Appointment: Identifiable {
    let id: String
    let startDate: Date
    let duration: Int
    let text: String
    let trainingTypeId: String
    let trainingTypeName: String
    let locationId: String
    let locationName: String
    let trainerId: String
    let trainerName: String
    let creditsCharged: Int
    let status: String
    let trainingPlanId: Int?
    let trainingPlanName: String?
}

extension Appointment {
    /// Baut ein Appointment aus einem rohen JSON-Dictionary.
    /// Das Backend liefert Datum und Uhrzeit getrennt ("date" + "starttime").
    init?(json: [String: Any]) {
        guard let id = jsonID(json["id"]) else { return nil }
        self.id = id

        // Datum + Uhrzeit sind Zürcher Ortszeit ohne Zeitzonen-Angabe
        let dateStr = (json["date"] as? String) ?? ""
        let timeStr = (json["starttime"] as? String) ?? (json["time_from"] as? String)
        guard let start = ZurichTime.date(day: dateStr, time: timeStr ?? "00:00") else { return nil }
        self.startDate = start

        self.duration        = Int("\(json["duration"] ?? 60)") ?? 60
        self.text            = (json["notes"] as? String) ?? (json["text"] as? String) ?? ""
        self.trainingTypeId  = jsonID(json["training_type_id"]) ?? ""
        self.trainingTypeName = (json["training_type_name"] as? String) ?? ""
        self.locationId      = jsonID(json["location_id"]) ?? ""
        self.locationName    = (json["location_name"] as? String) ?? ""
        self.trainerId       = jsonID(json["trainer_id"]) ?? ""

        if let trainer = json["trainer"] as? [String: Any] {
            let first = (trainer["firstname"] as? String) ?? ""
            let last  = (trainer["lastname"]  as? String) ?? ""
            self.trainerName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        } else {
            self.trainerName = ""
        }

        self.creditsCharged = Int("\(json["credits_charged"] ?? 0)") ?? 0
        self.status         = (json["status"] as? String) ?? ""

        self.trainingPlanId = jsonID(json["training_plan_id"] ?? json["trainingPlanId"]).flatMap { Int($0) }

        if let name = json["training_plan_name"] as? String {
            self.trainingPlanName = name
        } else if let plan = json["trainingPlan"] as? [String: Any] {
            self.trainingPlanName = plan["name"] as? String
        } else {
            self.trainingPlanName = nil
        }
    }
}

// MARK: - StartData

/// Antwort von `GET /api/client/start/:id` — Pendant zu `StartData` in Dart.
struct StartData {
    let firstName: String
    let lastName: String
    let totalCredits: Int
    let appointments: [Appointment]

    init(json: [String: Any]) {
        self.firstName    = (json["firstName"] as? String) ?? (json["firstname"] as? String) ?? ""
        self.lastName     = (json["lastName"]  as? String) ?? (json["lastname"]  as? String) ?? ""
        self.totalCredits = Int("\(json["credits"] ?? 0)") ?? 0

        if let list = json["appointments"] as? [[String: Any]] {
            self.appointments = list.compactMap { Appointment(json: $0) }
        } else {
            self.appointments = []
        }
    }
}
