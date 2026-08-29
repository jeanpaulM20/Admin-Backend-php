import Foundation

/// Dossier eines Kunden: Dateien, Anamnese, Leistungstests, Messwerte.
/// Dazu das Anlegen neuer Kunden und der Trainer-QR-Code.
struct ClientRecordsService {

    func files(clientId: Int) async throws -> [ClientFile] {
        let data = try await APIClient.shared.get("\(APIConfig.file)?client_id=\(clientId)")
        return Self.list(from: data).map(ClientFile.init(json:))
    }

    /// Der Bogen kann fehlen — dann ist nichts ausgefüllt, kein Fehler.
    func anamnese(clientId: Int) async throws -> Anamnese? {
        let data = try await APIClient.shared.get("\(APIConfig.anamnese)?client_id=\(clientId)")
        let json = try? JSONSerialization.jsonObject(with: data)
        if let object = json as? [String: Any], !object.isEmpty {
            return Anamnese(json: object)
        }
        if let array = json as? [[String: Any]], let first = array.first {
            return Anamnese(json: first)
        }
        return nil
    }

    func performanceTests(clientId: Int) async throws -> [PerformanceTest] {
        let data = try await APIClient.shared.get("\(APIConfig.performance)?client_id=\(clientId)")
        return Self.list(from: data).map(PerformanceTest.init(json:))
            .sorted { ($0.recordedAt ?? .distantPast) > ($1.recordedAt ?? .distantPast) }
    }

    func metrics(clientId: Int) async throws -> [MetricEntry] {
        let data = try await APIClient.shared.get("\(APIConfig.metric)?client_id=\(clientId)")
        return Self.list(from: data).map(MetricEntry.init(json:))
            .sorted { ($0.recordedAt ?? .distantPast) > ($1.recordedAt ?? .distantPast) }
    }

    /// Neuen Kunden anlegen. Feldnamen wie im Legacy-Backend (`e_mail`).
    func createClient(surname: String, name: String, email: String?,
                      phone: String?, mobile: String?, birthday: String?) async throws {
        var body: [String: Any] = ["surname": surname, "name": name]
        if let email, !email.isEmpty { body["e_mail"] = email }
        if let phone, !phone.isEmpty { body["phone"] = phone }
        if let mobile, !mobile.isEmpty { body["mobile"] = mobile }
        if let birthday, !birthday.isEmpty { body["birthday"] = birthday }
        _ = try await APIClient.shared.post(APIConfig.client, body: body)
    }

    /// QR-Code des Trainers — das Backend liefert ihn als Data-URL bzw. Base64.
    func qrCode(trainerId: Int) async throws -> String? {
        guard let json = try await APIClient.shared.getJSONObject("\(APIConfig.trainerQR)?id=\(trainerId)") else {
            return nil
        }
        return JSON.string(json, "code")
    }

    private static func list(from data: Data) -> [[String: Any]] {
        let json = try? JSONSerialization.jsonObject(with: data)
        if let array = json as? [[String: Any]] { return array }
        if let object = json as? [String: Any], let array = object["data"] as? [[String: Any]] {
            return array
        }
        return []
    }
}

/// Termine buchen und Verfügbarkeiten pflegen.
struct SchedulingService {

    /// Termin buchen. `training_type_id` ist im Flutter-Dialog fest 1 —
    /// die Typenauswahl gibt es dort (noch) nicht.
    func bookTraining(clientId: Int, date: Date, locationId: Int?) async throws {
        var body: [String: Any] = [
            "client_id": clientId,
            "date": Self.dayFormatter.string(from: date),
            "starttime": Self.timeFormatter.string(from: date),
            "training_type_id": 1,
        ]
        if let locationId { body["location_id"] = locationId }
        _ = try await APIClient.shared.post(APIConfig.training, body: body)
    }

    /// Termin absagen. Er bleibt im Kalender und wird als abgesagt geführt.
    func cancelTraining(id: Int) async throws {
        _ = try await APIClient.shared.post("\(APIConfig.training)/\(id)/cancel")
    }

    /// Plan als Online-Coaching in den Kundenkalender legen.
    func schedulePlan(planId: Int, clientId: Int, date: Date) async throws {
        _ = try await APIClient.shared.post("\(APIConfig.training)/schedule-plan", body: [
            "client_id": clientId,
            "training_plan_id": planId,
            "date": Self.dayFormatter.string(from: date),
            "starttime": Self.timeFormatter.string(from: date),
        ])
    }

    func deleteAvailability(slotId: Int) async throws {
        _ = try await APIClient.shared.delete("\(APIConfig.availability)/\(slotId)")
    }

    /// Einzelnes Zeitfenster an einem Tag — Ergänzung zur Serie für
    /// spontane Zusatztermine.
    func createAvailability(trainerId: Int, day: Date, from: Date, to: Date) async throws {
        _ = try await APIClient.shared.post(APIConfig.availability, body: [
            "trainerId": trainerId,
            "date": Self.dayFormatter.string(from: day),
            "from": Self.timeFormatter.string(from: from),
            "to": Self.timeFormatter.string(from: to),
        ])
    }

    /// Serienverfügbarkeit: Wochentage (1 = Montag) über einen Zeitraum.
    func createSerialAvailability(trainerId: Int, from: Date, to: Date,
                                  rangeStart: Date, rangeEnd: Date,
                                  weekdays: [Int]) async throws {
        _ = try await APIClient.shared.post(APIConfig.availabilitySerial, body: [
            "trainerId": trainerId,
            "from": Self.timeFormatter.string(from: from),
            "to": Self.timeFormatter.string(from: to),
            "rStart": Self.dayFormatter.string(from: rangeStart),
            "rEnd": Self.dayFormatter.string(from: rangeEnd),
            "days": weekdays.sorted(),
        ])
    }

    func locations() async throws -> [(id: Int, name: String)] {
        let data = try await APIClient.shared.get(APIConfig.locationList)
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { json in
            guard let id = JSON.int(json, "id"), let name = JSON.string(json, "name") else { return nil }
            return (id: id, name: name)
        }
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
}
