import Foundation
import CoreLocation

// MARK: - Modell

/// Eine Nachricht im Touren-Assistenten; Antworten können eine
/// berechnete Route tragen (KONZEPT-TOUREN-CHAT.md, C1).
struct AssistantMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var route: TourDetail? = nil
    /// Planungspunkte der Route — damit lässt sie sich im Planer anpassen.
    var plan: RoutePlan? = nil
}

/// Eine Route als Planung: Punkte in Reihenfolge, Aktivität, Rundkurs.
/// Der Routenplaner berechnet daraus dieselbe Route und lässt sie ändern.
struct RoutePlan {
    let name: String
    let points: [CLLocationCoordinate2D]
    let activity: RoundtripActivity
    let roundtrip: Bool

    init(name: String, points: [CLLocationCoordinate2D], activity: RoundtripActivity, roundtrip: Bool) {
        self.name = name
        self.points = points
        self.activity = activity
        self.roundtrip = roundtrip
    }

    init?(json: [String: Any]?, name: String) {
        guard let json else { return nil }
        let points: [CLLocationCoordinate2D] = (json["points"] as? [[String: Any]] ?? []).compactMap {
            guard let lat = Double("\($0["lat"] ?? "")"),
                  let lon = Double("\($0["lon"] ?? "")") else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard points.count >= 2, points.count <= RoutePlannerModel.maxPoints else { return nil }
        self.init(name: name, points: points,
                  activity: RoundtripActivity(rawValue: json["activity"] as? String ?? "") ?? .wandern,
                  roundtrip: (json["roundtrip"] as? Bool) ?? false)
    }
}

// MARK: - Service

enum TourAssistantService {
    /// Chat-Verlauf ans Backend; Antwort = Text + optionale Route.
    static func send(clientId: String, history: [AssistantMessage]) async throws -> AssistantMessage {
        let messages = history.map { m in
            ["role": m.role == .user ? "user" : "assistant", "content": m.text]
        }
        guard let json = try await APIClient.shared.postJSONObject(
            "/api/client/tours/assistant/\(clientId)",
            body: ["messages": messages],
            timeout: 90
        ) else {
            throw APIError(statusCode: -2, message: "Antwort konnte nicht gelesen werden")
        }
        let reply = json["reply"] as? String ?? "Da ist etwas schiefgelaufen."
        var route: TourDetail?
        var plan: RoutePlan?
        if let routeJson = json["route"] as? [String: Any] {
            route = TourDetail(json: routeJson)
            plan = RoutePlan(json: routeJson["plan"] as? [String: Any], name: route?.name ?? "Route")
        }
        return AssistantMessage(role: .assistant, text: reply, route: route, plan: plan)
    }

    /// Demo-Modus: vorbereitete Antwort mit Beispiel-Rundtour (ohne Backend).
    static func demoReply(for _: String) -> AssistantMessage {
        let lat = 47.31, lon = 8.52, km = 8.0
        let r = km / (2 * .pi), latKm = 110.574, lonKm = 111.32 * cos(lat * .pi / 180)
        return AssistantMessage(
            role: .assistant,
            text: "Im Demo-Modus rechne ich mit Beispieldaten: Hier ist eine "
                + "8-km-Wanderrunde ab Adliswil — 1 Std 55 Min, sanfte Hügel. "
                + "Mit echtem Konto suche ich dir Routen in der ganzen Schweiz.",
            route: TourService.demoRoundtrip(lat: lat, lon: lon,
                                             distanceKm: km, activity: .wandern),
            // Vier Punkte auf dem Kreis der Beispielrunde, als Rundkurs
            plan: RoutePlan(
                name: "Rundtour · 8.0 km",
                points: [
                    CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    CLLocationCoordinate2D(latitude: lat + r / latKm, longitude: lon - r / lonKm),
                    CLLocationCoordinate2D(latitude: lat + 2 * r / latKm, longitude: lon),
                    CLLocationCoordinate2D(latitude: lat + r / latKm, longitude: lon + r / lonKm),
                ],
                activity: .wandern, roundtrip: true)
        )
    }
}
