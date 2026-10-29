import Foundation

// MARK: - AvailabilityInterval

/// Pendant zu `AvailabilityInterval` in `models/calendar_data.dart`.
struct AvailabilityInterval: Identifiable {
    let id: String
    let trainerId: String
    let date: String          // "yyyy-MM-dd"
    let from: String          // "HH:mm"
    let to: String            // "HH:mm"
    let trainingTypeId: String?
    let locationId: String?

    init(json: [String: Any]) {
        // IDs kommen als Zahl → robust lesen
        self.id             = jsonID(json["id"]) ?? UUID().uuidString
        self.trainerId      = jsonID(json["trainer_id"]) ?? ""
        self.date           = String(((json["date"] as? String) ?? "").prefix(10))
        self.from           = (json["from"] as? String) ?? ""
        self.to             = (json["to"]   as? String) ?? ""
        self.trainingTypeId = jsonID(json["training_type_id"])
        self.locationId     = jsonID(json["location_id"])
    }
}

// MARK: - TrainerBooking

/// Vorhandene Buchung eines Trainers (für Puffer-/Konflikt-Berechnung).
struct TrainerBooking: Identifiable {
    let id: String
    let trainerId: String
    let date: String
    let starttime: String
    let duration: Int
    let locationId: String?
    let status: String

    init(json: [String: Any]) {
        self.id         = jsonID(json["id"]) ?? UUID().uuidString
        self.trainerId  = jsonID(json["trainer_id"]) ?? ""
        self.date       = String(((json["date"] as? String) ?? "").prefix(10))
        self.starttime  = (json["starttime"] as? String) ?? "00:00"
        self.duration   = Int("\(json["duration"] ?? 60)") ?? 60
        self.locationId = jsonID(json["location_id"])
        self.status     = (json["status"] as? String) ?? ""
    }
}

// MARK: - LocationInfo

/// Standort mit Puffer-Minuten zwischen Buchungen.
struct LocationInfo: Identifiable {
    let id: String
    let name: String
    let address: String?
    let bufferMinutes: Int

    init(json: [String: Any]) {
        self.id            = jsonID(json["id"]) ?? ""
        self.name          = (json["name"] as? String) ?? ""
        self.address       = json["address"] as? String
        self.bufferMinutes = Int("\(json["buffer_minutes"] ?? 30)") ?? 30
    }
}

// MARK: - CalendarData

/// Pendant zu `CalendarData` in `models/calendar_data.dart`.
struct CalendarData {
    let defaultTrainerId: String?
    let defaultTypeId: String?
    let minimumDate: Date
    let maximumDate: Date
    let credits: Int
    let trainers: [Trainer]
    let trainingTypes: [TrainingType]
    let appointments: [Appointment]
    let availabilityIntervals: [AvailabilityInterval]
    let trainerBookings: [TrainerBooking]
    let locations: [LocationInfo]

    init(json: [String: Any]) {
        let trainers = ((json["trainers"] as? [[String: Any]])?.map { Trainer(json: $0) } ?? [])
            .filter { !$0.id.isEmpty }
        let types    = ((json["training_types"] as? [[String: Any]])?.map { TrainingType(json: $0) } ?? [])
            .filter { !$0.id.isEmpty }

        let rawAppts = (json["appointments"] as? [[String: Any]]) ?? []
        let appts = rawAppts.compactMap { Appointment(json: $0) }

        let avail = (json["availability"] as? [[String: Any]])?.map { AvailabilityInterval(json: $0) } ?? []
        let bookings = (json["trainer_bookings"] as? [[String: Any]])?.map { TrainerBooking(json: $0) } ?? []
        let locs = ((json["locations"] as? [[String: Any]])?.map { LocationInfo(json: $0) } ?? [])
            .filter { !$0.id.isEmpty }

        self.trainers              = trainers
        self.trainingTypes         = types
        self.appointments          = appts
        self.availabilityIntervals = avail
        self.trainerBookings       = bookings
        self.locations             = locs
        self.credits               = Int("\(json["credits"] ?? 0)") ?? 0
        self.defaultTrainerId      = trainers.first?.id
        self.defaultTypeId         = types.first?.id
        let cal = ZurichTime.calendar
        let today = cal.startOfDay(for: Date())
        self.minimumDate           = cal.date(byAdding: .day, value: -30, to: today) ?? today
        self.maximumDate           = cal.date(byAdding: .day, value:  90, to: today) ?? today
    }

    /// Ist der Trainer von `startMin` bis `endMin` am Standort frei? Gleiche
    /// Regel wie das Backend: gleicher Standort ohne Puffer, sonst der grössere
    /// Standort-Puffer; Fremdkalender (`status == "external"`) ohne Puffer.
    func isTrainerFree(trainerId: String, locationId: String?, dateStr: String,
                       startMin: Int, endMin: Int) -> Bool {
        let buffers = Dictionary(locations.map { ($0.id, $0.bufferMinutes) },
                                 uniquingKeysWith: { first, _ in first })
        for b in trainerBookings {
            let status = b.status.lowercased()
            guard b.trainerId == trainerId, b.date == dateStr, status != "cancelled",
                  let bStart = Self.minutes(b.starttime) else { continue }
            let bEnd = bStart + b.duration
            let buffer: Int
            if status == "external" || (locationId != nil && b.locationId == locationId) {
                buffer = 0
            } else {
                buffer = max(locationId.flatMap { buffers[$0] } ?? 30,
                             b.locationId.flatMap { buffers[$0] } ?? 30)
            }
            if startMin < bEnd + buffer && bStart < endMin + buffer { return false }
        }
        return true
    }

    /// "HH:mm" bzw. "HH:mm:ss" → Minuten seit Mitternacht.
    static func minutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }
}
