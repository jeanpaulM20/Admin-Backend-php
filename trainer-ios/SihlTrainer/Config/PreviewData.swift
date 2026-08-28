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
