import Foundation

// MARK: - Modell

/// Eine Nachricht im Touren-Assistenten; Antworten können eine
/// berechnete Route tragen (KONZEPT-TOUREN-CHAT.md, C1).
struct AssistantMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var route: TourDetail? = nil
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
        if let routeJson = json["route"] as? [String: Any] {
            route = TourDetail(json: routeJson)
        }
        return AssistantMessage(role: .assistant, text: reply, route: route)
    }

    /// Demo-Modus: vorbereitete Antwort mit Beispiel-Rundtour (ohne Backend).
    static func demoReply(for _: String) -> AssistantMessage {
        AssistantMessage(
            role: .assistant,
            text: "Im Demo-Modus rechne ich mit Beispieldaten: Hier ist eine "
                + "8-km-Wanderrunde ab Adliswil — 1 Std 55 Min, sanfte Hügel. "
                + "Mit echtem Konto suche ich dir Routen in der ganzen Schweiz.",
            route: TourService.demoRoundtrip(lat: 47.31, lon: 8.52,
                                             distanceKm: 8, activity: .wandern)
        )
    }
}
