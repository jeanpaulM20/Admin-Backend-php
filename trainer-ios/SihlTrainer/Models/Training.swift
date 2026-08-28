import Foundation

/// Pendant zu `models/training.dart` — ein Termin/Training im Kalender.
struct Training: Identifiable, Equatable {
    let id: Int
    let title: String?
    let startTime: Date?
    let endTime: Date?
    let day: String?
    let timeFrom: String?
    let timeTo: String?
    let clientId: Int?
    let clientName: String?
    let trainerId: Int?
    let trainerName: String?
    let locationId: Int?
    let locationName: String?
    let trainingType: String?
    let status: String?
    let notes: String?
    let isCancelled: Bool
    let cancelledAt: Date?
    let trainingPlanId: Int?
    let trainingPlanName: String?

    init(json: [String: Any]) {
        id = JSON.int(json, "id", "training_id") ?? 0
        title = JSON.string(json, "title", "name")

        // Erst kombinierte Datetime-Felder, dann date + getrennte Zeit
        // (NestJS: "starttime" ohne Unterstrich, PHP: "time_from"/"from").
        let start = JSON.date(JSON.string(json, "start", "start_time", "datetime_from"))
        let dayValue = JSON.string(json, "date", "training_date")
        let from = JSON.string(json, "time_from", "starttime", "from", "start_time")
        startTime = start ?? JSON.date(day: dayValue, time: from)
        endTime = JSON.date(JSON.string(json, "end", "end_time", "datetime_to"))

        day = dayValue
        timeFrom = JSON.string(json, "time_from", "starttime", "from")
        timeTo = JSON.string(json, "time_to", "to")

        // NestJS bettet client/trainer als Objekt ein, PHP liefert flache Felder.
        let clientObject = json["client"] as? [String: Any]
        let trainerObject = json["trainer"] as? [String: Any]

        clientId = JSON.intNonZero(json, "client_id", "clientId")
        if let name = JSON.string(json, "client_name") {
            clientName = name
        } else if let clientObject {
            clientName = Training.name(from: clientObject)
        } else {
            clientName = Training.name(from: json, first: "client_first_name", last: "client_last_name")
        }

        trainerId = JSON.intNonZero(json, "trainer_id", "trainerId")
        if let name = JSON.string(json, "trainer_name") {
            trainerName = name
        } else if let trainerObject {
            trainerName = Training.name(from: trainerObject)
        } else {
            trainerName = nil
        }

        locationId = JSON.intNonZero(json, "location_id", "locationId")
        locationName = JSON.string(json, "location_name", "location")
        trainingType = JSON.string(json, "training_type", "trainingType", "type")
        status = JSON.string(json, "status", "training_status")
        notes = JSON.string(json, "notes", "comment")
        isCancelled = JSON.bool(json, "cancelled", "is_cancelled", "isCancelled")
            || (JSON.string(json, "status", "training_status")?.lowercased() == "cancelled")
        cancelledAt = JSON.date(JSON.string(json, "cancelled_at", "cancelledAt"))
        trainingPlanId = JSON.intNonZero(json, "training_plan_id", "trainingplan_id", "trainingPlanId")
        trainingPlanName = JSON.string(json, "training_plan_name", "trainingplan_name")
    }

    private static func name(from json: [String: Any],
                             first: String = "firstname",
                             last: String = "lastname") -> String? {
        let firstName = JSON.string(json, first, "first_name", "name") ?? ""
        let lastName = JSON.string(json, last, "last_name", "surname") ?? ""
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? nil : full
    }

    /// Kurzfristige Absage: weniger als 12 Stunden vor Beginn abgesagt. Diese
    /// Termine werden weiterhin verrechnet und bleiben im Kalender sichtbar.
    var isLateCancellation: Bool {
        guard isCancelled, let startTime, let cancelledAt else { return false }
        return startTime.timeIntervalSince(cancelledAt) < 12 * 3600
    }
}
