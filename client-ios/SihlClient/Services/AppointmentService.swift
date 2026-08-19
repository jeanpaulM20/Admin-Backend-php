import Foundation

/// Pendant zu `services/appointment_service.dart`.
/// Alle Methoden sind stateless; Instanz bei Bedarf wegwerfen oder wiederverwenden.
struct AppointmentService {

    func getStartData(clientId: String) async throws -> StartData {
        let data = try await APIClient.shared.get("api/client/start/\(clientId)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(statusCode: 500, message: "Ungültige Startdaten")
        }
        return StartData(json: json)
    }

    func bookAppointment(
        clientId: String,
        trainerId: String,
        trainingTypeId: String,
        date: String,
        starttime: String,
        locationId: String?,
        duration: Int
    ) async throws {
        var body: [String: Any] = [
            "trainer_id":        Int(trainerId)       as Any? ?? trainerId,
            "training_type_id":  Int(trainingTypeId)  as Any? ?? trainingTypeId,
            "date":      date,
            "starttime": starttime,
            "duration":  duration,
        ]
        if let loc = locationId, !loc.isEmpty {
            body["location_id"] = Int(loc) as Any? ?? loc
        }
        _ = try await APIClient.shared.post("api/client/appointment/\(clientId)", body: body)
    }

    /// Gibt den vollen Response-Body zurück (enthält `creditRefunded`), oder `nil` wenn
    /// `success != true` — analog zur Flutter-Implementierung.
    func cancelAppointment(clientId: String, appointmentId: String) async throws -> [String: Any]? {
        let data = try await APIClient.shared.delete(
            "api/client/appointment/\(clientId)/\(appointmentId)"
        )
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["success"] as? Bool == true
        else { return nil }
        return json
    }
}
