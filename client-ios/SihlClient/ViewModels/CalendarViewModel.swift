import Foundation

// MARK: - Internal slot types

struct CalTimeSlot: Identifiable {
    let id = UUID()
    let startMin: Int
    var timeStr:    String { CalTimeSlot.fmt(startMin) }
    var endTimeStr: String { CalTimeSlot.fmt(startMin + 60) }
    /// „06:00–07:00" — Start und Ende in einer Zeile, damit die Endzeit
    /// nicht wie die Startzeit des nächsten Slots gelesen wird.
    var rangeStr:   String { "\(timeStr)–\(endTimeStr)" }

    static func fmt(_ min: Int) -> String {
        String(format: "%02d:%02d", min / 60, min % 60)
    }
}

struct SlotOption {
    let trainerId: String
    let locationId: String?
    let trainingTypeId: String?
}

struct SlotSelection {
    let trainerId: String
    let locationId: String
    let trainingTypeId: String?
}

// MARK: - CalendarViewModel

/// Pendant zu `providers/appointment_provider.dart` (Kalender-Teil) +
/// `providers/preference_provider.dart`.
@MainActor @Observable
final class CalendarViewModel {

    // State
    var isLoading    = false
    var error: String?
    var calendarData: CalendarData?

    // Preferences
    var prefTrainerId:  String?
    var prefLocationId: String?

    // Action flags
    var isBooking    = false
    var isCancelling = false
    var toast: AppToast?

    // Calendar navigation state
    var selectedDate:  Date = Date()
    var displayMonth:  Date = {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: c) ?? Date()
    }()

    private let apptService = AppointmentService()
    private let prefService  = PreferenceService()

    // MARK: - Load

    func load(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true; error = nil

        async let calTask   = apptService.getCalendarData(clientId: clientId)
        async let prefTask  = prefService.getPreferences(clientId: clientId)

        do { calendarData = try await calTask } catch { self.error = error.localizedDescription }
        if let prefs = try? await prefTask {
            prefTrainerId  = prefs["trainer_id"] ?? nil
            prefLocationId = prefs["location_id"] ?? nil
        }
        isLoading = false
    }

    // MARK: - Calendar Queries

    func eventsForDay(_ day: Date) -> [Appointment] {
        guard let cal = calendarData else { return [] }
        return cal.appointments
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
            .sorted {
                let ac = $0.status.lowercased() == "cancelled" ? 1 : 0
                let bc = $1.status.lowercased() == "cancelled" ? 1 : 0
                return ac == bc ? $0.startDate < $1.startDate : ac < bc
            }
    }

    func availabilityForDay(_ day: Date) -> [AvailabilityInterval] {
        guard let cal = calendarData else { return [] }
        let dateStr = dayString(day)
        return cal.availabilityIntervals.filter { $0.date == dateStr }
    }

    func slotsForDay(_ day: Date) -> [CalTimeSlot] {
        guard let cal = calendarData else { return [] }
        return generateSlots(day: day, calData: cal)
    }

    func optionsForSlot(_ slot: CalTimeSlot, day: Date) -> [SlotOption] {
        guard let cal = calendarData else { return [] }
        return getOptionsForSlot(slot, day: day, calData: cal)
    }

    /// Simplified check for dot marker: does any availability window allow a 60-min
    /// slot that starts ≥12h from now? (Does not check trainer conflicts.)
    func hasAnyBookableWindow(for day: Date) -> Bool {
        let avail = availabilityForDay(day)
        if avail.isEmpty { return false }
        let minBookable = Date().addingTimeInterval(12 * 3600)
        let cal = Calendar.current
        for a in avail {
            guard let toMin = parseTime(a.to) else { continue }
            let latestStartMin = toMin - 60
            guard latestStartMin >= 0 else { continue }
            let latest = cal.date(bySettingHour: latestStartMin / 60,
                                  minute: latestStartMin % 60,
                                  second: 0, of: day) ?? day
            if latest >= minBookable { return true }
        }
        return false
    }

    // MARK: - Booking

    func book(slot: CalTimeSlot, selection: SlotSelection, clientId: String) async {
        guard !isBooking else { return }
        isBooking = true; toast = nil

        guard let cal = calendarData else { isBooking = false; return }
        let typeId = selection.trainingTypeId ?? cal.defaultTypeId ?? ""

        do {
            try await apptService.bookAppointment(
                clientId: clientId,
                trainerId: selection.trainerId,
                trainingTypeId: typeId,
                date: dayString(selectedDate),
                starttime: slot.timeStr,
                locationId: selection.locationId,
                duration: 60
            )
            // Save preferences (silent fail)
            try? await prefService.savePreferences(clientId: clientId, prefs: [
                "trainer_id":      selection.trainerId,
                "training_type_id": typeId,
                "location_id":     selection.locationId,
            ])
            prefTrainerId  = selection.trainerId
            prefLocationId = selection.locationId
            // Refresh calendar
            await load(clientId: clientId)
            toast = AppToast(message: "Termin erfolgreich gebucht!", style: .success)
        } catch {
            toast = AppToast(message: error.localizedDescription, style: .error)
        }
        isBooking = false
    }

    /// Returns `creditRefunded` flag (from backend), or throws on error.
    func cancel(appointment: Appointment, clientId: String) async throws -> Bool {
        isCancelling = true
        defer { isCancelling = false }
        let result = try await apptService.cancelAppointment(
            clientId: clientId, appointmentId: appointment.id
        )
        await load(clientId: clientId)
        return result?["creditRefunded"] as? Bool ?? false
    }

    // MARK: - Slot Generation (1:1 aus Flutter portiert)

    private func generateSlots(day: Date, calData: CalendarData) -> [CalTimeSlot] {
        let slotDuration = 60
        let slotStep     = 30
        let dateStr      = dayString(day)
        let now          = Date()
        let locBuffers   = buildLocationBuffers(calData)

        let dayAvail = calData.availabilityIntervals.filter { $0.date == dateStr }
        if dayAvail.isEmpty { return [] }

        // Alle möglichen 30-Min-Startzeiten aus den Verfügbarkeitsfenstern
        var allMinutes = Set<Int>()
        for a in dayAvail {
            guard let fromMin = parseTime(a.from), let toMin = parseTime(a.to) else { continue }
            var m = fromMin
            while m + slotDuration <= toMin { allMinutes.insert(m); m += slotStep }
        }
        if allMinutes.isEmpty { return [] }

        let cal = Calendar.current
        var slots: [CalTimeSlot] = []

        for startMin in allMinutes.sorted() {
            let endMin = startMin + slotDuration

            // 12h Vorlauf
            guard let slotTime = cal.date(bySettingHour: startMin / 60,
                                          minute: startMin % 60,
                                          second: 0, of: day),
                  slotTime.timeIntervalSince(now) / 3600.0 >= 12 else { continue }

            // Client-Doppelbuchung prüfen
            var clientConflict = false
            for a in calData.appointments {
                guard a.status.lowercased() != "cancelled",
                      cal.isDate(a.startDate, inSameDayAs: day) else { continue }
                let aStart = a.startDate.hour60 * 60 + a.startDate.minute60
                let aEnd   = aStart + a.duration
                if startMin < aEnd && aStart < endMin { clientConflict = true; break }
            }
            if clientConflict { continue }

            // Mind. ein Trainer+Standort frei?
            var anyFree = false
            for a in dayAvail {
                guard let fromMin = parseTime(a.from), let toMin = parseTime(a.to),
                      startMin >= fromMin, endMin <= toMin else { continue }
                if isTrainerFree(trainerId: a.trainerId, locationId: a.locationId,
                                 startMin: startMin, endMin: endMin,
                                 dateStr: dateStr, calData: calData, locBuffers: locBuffers) {
                    anyFree = true; break
                }
            }
            if !anyFree { continue }

            slots.append(CalTimeSlot(startMin: startMin))
        }
        return slots
    }

    private func getOptionsForSlot(_ slot: CalTimeSlot, day: Date, calData: CalendarData) -> [SlotOption] {
        let dateStr  = dayString(day)
        let startMin = slot.startMin
        let endMin   = startMin + 60
        let locBufs  = buildLocationBuffers(calData)
        let dayAvail = calData.availabilityIntervals.filter { $0.date == dateStr }

        var options: [SlotOption] = []
        for a in dayAvail {
            guard let fromMin = parseTime(a.from), let toMin = parseTime(a.to),
                  startMin >= fromMin, endMin <= toMin else { continue }
            if isTrainerFree(trainerId: a.trainerId, locationId: a.locationId,
                             startMin: startMin, endMin: endMin,
                             dateStr: dateStr, calData: calData, locBuffers: locBufs) {
                options.append(SlotOption(trainerId: a.trainerId,
                                          locationId: a.locationId,
                                          trainingTypeId: a.trainingTypeId))
            }
        }
        // Deduplizieren nach trainer+location
        var seen = Set<String>()
        return options.filter { o in
            let key = "\(o.trainerId):\(o.locationId ?? "")"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Helpers

    private func isTrainerFree(trainerId: String, locationId: String?,
                                startMin: Int, endMin: Int,
                                dateStr: String, calData: CalendarData,
                                locBuffers: [String: Int]) -> Bool {
        for b in calData.trainerBookings {
            guard b.trainerId == trainerId,
                  b.date == dateStr,
                  b.status.lowercased() != "cancelled",
                  let bStart = parseTime(b.starttime) else { continue }
            let bEnd = bStart + b.duration
            let sameLocation = locationId != nil && b.locationId != nil && b.locationId == locationId
            let buffer: Int
            if sameLocation {
                buffer = 0
            } else {
                let reqBuf  = locationId != nil ? (locBuffers[locationId!]  ?? 30) : 30
                let exiBuf  = b.locationId != nil ? (locBuffers[b.locationId!] ?? 30) : 30
                buffer = max(reqBuf, exiBuf)
            }
            if startMin < bEnd + buffer && bStart < endMin + buffer { return false }
        }
        return true
    }

    private func buildLocationBuffers(_ calData: CalendarData) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: calData.locations.map { ($0.id, $0.bufferMinutes) })
    }

    func parseTime(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    private func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

// MARK: - Date helpers (private)

private extension Date {
    var hour60:   Int { Calendar.current.component(.hour,   from: self) }
    var minute60: Int { Calendar.current.component(.minute, from: self) }
}
