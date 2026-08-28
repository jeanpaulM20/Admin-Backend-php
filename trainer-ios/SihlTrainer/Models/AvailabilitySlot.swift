import Foundation

/// Ein Verfügbarkeitsfenster des Trainers.
/// Pendant zu `models/availability.dart`.
struct AvailabilitySlot: Identifiable, Equatable {
    let id: Int
    let startTime: Date?
    let endTime: Date?
    let timeFrom: String?
    let timeTo: String?
    let trainerId: Int?
    let locationId: Int?
    let locationName: String?
    let isBooked: Bool
    let status: String?

    init(json: [String: Any]) {
        id = JSON.int(json, "id", "availability_id") ?? 0
        let start = JSON.date(JSON.string(json, "start", "start_time", "datetime_from"))
        startTime = start ?? JSON.date(day: JSON.string(json, "date"),
                                       time: JSON.string(json, "time_from", "from"))
        endTime = JSON.date(JSON.string(json, "end", "end_time", "datetime_to"))
            ?? JSON.date(day: JSON.string(json, "date"), time: JSON.string(json, "time_to", "to"))
        timeFrom = JSON.string(json, "time_from", "from")
        timeTo = JSON.string(json, "time_to", "to")
        trainerId = JSON.intNonZero(json, "trainer_id", "trainerId")
        locationId = JSON.intNonZero(json, "location_id", "locationId")
        locationName = JSON.string(json, "location_name", "location")
        status = JSON.string(json, "status")
        let statusValue = JSON.string(json, "status")
        isBooked = statusValue == "booked" || statusValue == "reserved"
            || JSON.bool(json, "is_booked", "booked")
    }

    /// Tag ohne Uhrzeit — Schlüssel für die Tagesgruppierung im Kalender.
    var day: Date? {
        guard let startTime else { return nil }
        return Calendar.current.startOfDay(for: startTime)
    }
}
