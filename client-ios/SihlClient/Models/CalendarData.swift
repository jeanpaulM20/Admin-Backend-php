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
        self.id             = "\(json["id"] ?? "")"
        self.trainerId      = "\(json["trainer_id"] ?? "")"
        self.date           = (json["date"] as? String) ?? ""
        self.from           = (json["from"] as? String) ?? ""
        self.to             = (json["to"]   as? String) ?? ""
        self.trainingTypeId = (json["training_type_id"] as? String)
        self.locationId     = (json["location_id"] as? String)
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
        self.id         = "\(json["id"] ?? "")"
        self.trainerId  = "\(json["trainer_id"] ?? "")"
        self.date       = (json["date"] as? String) ?? ""
        self.starttime  = (json["starttime"] as? String) ?? "00:00"
        self.duration   = Int("\(json["duration"] ?? 60)") ?? 60
        self.locationId = (json["location_id"] as? String)
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
        self.id            = "\(json["id"] ?? "")"
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
        let trainers = (json["trainers"] as? [[String: Any]])?.map { Trainer(json: $0) } ?? []
        let types    = (json["training_types"] as? [[String: Any]])?.map { TrainingType(json: $0) } ?? []

        let rawAppts = (json["appointments"] as? [[String: Any]]) ?? []
        let appts = rawAppts.compactMap { Appointment(json: $0) }

        let avail = (json["availability"] as? [[String: Any]])?.map { AvailabilityInterval(json: $0) } ?? []
        let bookings = (json["trainer_bookings"] as? [[String: Any]])?.map { TrainerBooking(json: $0) } ?? []
        let locs = (json["locations"] as? [[String: Any]])?.map { LocationInfo(json: $0) } ?? []

        self.trainers              = trainers
        self.trainingTypes         = types
        self.appointments          = appts
        self.availabilityIntervals = avail
        self.trainerBookings       = bookings
        self.locations             = locs
        self.credits               = Int("\(json["credits"] ?? 0)") ?? 0
        self.defaultTrainerId      = trainers.first?.id
        self.defaultTypeId         = types.first?.id
        self.minimumDate           = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        self.maximumDate           = Calendar.current.date(byAdding: .day, value:  90, to: Date()) ?? Date()
    }
}
