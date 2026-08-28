#if DEBUG
import Foundation

/// Beispieldaten für den Vorschaumodus.
///
/// Nur in Debug-Builds vorhanden: Der angemeldete Teil der App lässt sich so
/// ohne Passcode und ohne Backend ansehen und auf iPhone wie iPad prüfen.
/// In Release-Builds existiert diese Datei nicht im Binary.
enum PreviewData {

    static let trainer = Trainer(json: [
        "id": 1,
        "name": "Vorschau",
        "surname": "Trainer",
        "email": "vorschau@sihltraining.ch",
    ])

    static let clients: [Client] = [
        [
            "id": 12, "name": "Anna", "surname": "Bühler",
            "email": "anna.buehler@example.ch", "phone": "079 123 45 67",
            "training_type": "Athletik", "location_name": "Studio Sihlcity",
            "min_heart_rate": 118, "max_heart_rate": 176,
        ],
        [
            "id": 22, "name": "Marco", "surname": "Steiner",
            "email": "marco.steiner@example.ch", "phone": "078 987 65 43",
            "training_type": "Ausdauer", "location_name": "Studio Sihlcity",
        ],
        [
            "id": 23, "name": "Lena", "surname": "Achermann",
            "email": "lena.achermann@example.ch",
            "training_type": "Kraft", "location_name": "Studio Wiedikon",
        ],
        [
            "id": 31, "name": "Tobias", "surname": "Frei",
            "phone": "076 222 11 00",
            "training_type": "Mental", "location_name": "Online",
        ],
    ].map(Client.init(json:))

    static let conversations: [Conversation] = [
        ["client_id": 12, "client_name": "Anna Bühler",
         "last_message": "Super, bis Freitag um 17 Uhr!", "unread_count": 2],
        ["client_id": 22, "client_name": "Marco Steiner",
         "last_message": "Kann ich den Termin verschieben?", "unread_count": 1],
        ["client_id": 23, "client_name": "Lena Achermann",
         "last_message": "Danke für den neuen Plan.", "unread_count": 0],
    ].map(Conversation.init(json:))

    static let messages: [ChatMessage] = [
        ["id": 1, "message": "Grüezi! Wie war die Einheit gestern?",
         "read_trainer": 1, "read_client": 0],
        ["id": 2, "message": "Sehr gut — die Knie haben gehalten.",
         "read_trainer": 1, "read_client": 1],
        ["id": 3, "message": "Perfekt. Dann erhöhen wir am Freitag das Gewicht.",
         "read_trainer": 1, "read_client": 0],
        ["id": 4, "message": "Super, bis Freitag um 17 Uhr!",
         "read_trainer": 0, "read_client": 1],
    ].map(ChatMessage.init(json:))

    static var availability: [AvailabilitySlot] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()

        func slot(_ id: Int, dayOffset: Int, from: Int, to: Int, booked: Bool = false) -> AvailabilitySlot {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return AvailabilitySlot(json: [
                "id": id,
                "date": formatter.string(from: day),
                "time_from": String(format: "%02d:00:00", from),
                "time_to": String(format: "%02d:00:00", to),
                "location_name": "Studio Sihlcity",
                "status": booked ? "booked" : "free",
            ])
        }

        return [
            slot(201, dayOffset: 0, from: 16, to: 20),
            slot(202, dayOffset: 1, from: 8, to: 12),
            slot(203, dayOffset: 1, from: 14, to: 18, booked: true),
            slot(204, dayOffset: 2, from: 9, to: 13),
            slot(205, dayOffset: 3, from: 16, to: 20),
        ]
    }

    static var trainings: [Training] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()

        func entry(_ id: Int, _ clientId: Int, _ client: String, _ type: String,
                   dayOffset: Int, hour: Int, cancelled: Bool = false) -> Training {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return Training(json: [
                "id": id,
                "client_id": clientId,
                "client_name": client,
                "training_type": type,
                "location_name": "Studio Sihlcity",
                "date": formatter.string(from: day),
                "starttime": String(format: "%02d:00:00", hour),
                "status": cancelled ? "cancelled" : "confirmed",
            ])
        }

        return [
            entry(101, 12, "Anna Bühler", "Athletik", dayOffset: 0, hour: 17),
            entry(102, 22, "Marco Steiner", "Ausdauer", dayOffset: 0, hour: 19),
            entry(103, 23, "Lena Achermann", "Kraft", dayOffset: 1, hour: 8),
            entry(104, 31, "Tobias Frei", "Mental", dayOffset: 1, hour: 12, cancelled: true),
            entry(105, 12, "Anna Bühler", "Athletik", dayOffset: 3, hour: 17),
        ]
    }
}
#endif
