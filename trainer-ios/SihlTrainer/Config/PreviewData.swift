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

    static let exerciseGroups: [ExerciseGroup] = [
        ["id": 1, "name": "Langhantel"],
        ["id": 2, "name": "Kurzhantel"],
        ["id": 3, "name": "Maschine"],
        ["id": 4, "name": "Körpergewicht"],
    ].map(ExerciseGroup.init(json:))

    static let exercises: [Exercise] = [
        ["id": 1, "name": "Kniebeuge", "group_id": 1, "body_region": "Unterkörper",
         "group": ["id": 1, "name": "Langhantel"], "primary_muscle_group": "Quadrizeps"],
        ["id": 2, "name": "Kreuzheben", "group_id": 1, "body_region": "Ganzkörper",
         "group": ["id": 1, "name": "Langhantel"], "primary_muscle_group": "Rückenstrecker"],
        ["id": 3, "name": "Bankdrücken", "group_id": 1, "body_region": "Oberkörper",
         "group": ["id": 1, "name": "Langhantel"], "primary_muscle_group": "Brust"],
        ["id": 4, "name": "Schulterdrücken", "group_id": 2, "body_region": "Oberkörper",
         "group": ["id": 2, "name": "Kurzhantel"], "primary_muscle_group": "Schulter"],
        ["id": 5, "name": "Latzug", "group_id": 3, "body_region": "Oberkörper",
         "group": ["id": 3, "name": "Maschine"], "primary_muscle_group": "Latissimus"],
        ["id": 6, "name": "Beinpresse", "group_id": 3, "body_region": "Unterkörper",
         "group": ["id": 3, "name": "Maschine"], "primary_muscle_group": "Quadrizeps"],
        ["id": 7, "name": "Klimmzug", "group_id": 4, "body_region": "Oberkörper",
         "group": ["id": 4, "name": "Körpergewicht"], "primary_muscle_group": "Latissimus"],
        ["id": 8, "name": "Plank", "group_id": 4, "body_region": "Rumpf",
         "group": ["id": 4, "name": "Körpergewicht"], "primary_muscle_group": "Bauch"],
    ].map(Exercise.init(json:))

    static let files: [ClientFile] = [
        ["id": 1, "name": "Anamnesebogen.pdf", "file": "/api/file/1", "date": "2026-03-14"],
        ["id": 2, "name": "Trainingsplan Juli.pdf", "file": "/api/file/2", "date": "2026-07-02"],
    ].map(ClientFile.init(json:))

    static let anamnese = Anamnese(json: [
        "profession": "Physiotherapeutin",
        "activities": 1,
        "sportarts": "Laufen, Klettern",
        "sportarts_scope": "3× pro Woche",
        "sleep_week": 7,
        "sleep_weekend": 8,
        "goals": "Rückenbeschwerden loswerden, Grundlagenausdauer aufbauen.",
        "injury": true,
        "injury_type": "Bandscheibenvorfall",
        "injury_bodypart": "LWS",
        "disease_circulatory_disorder": true,
        "taking_drugs": false,
    ])

    static var performanceTests: [PerformanceTest] {
        [PerformanceTest(json: [
            "id": 1, "recorded_at": "2026-08-10", "points": 78,
            "hamstrings": 12, "calfs": 9, "adductors": 14,
            "pullups": 6, "pushups": 22, "forearm_support": 95,
            "sensomotoric": 7.4, "reaction": 0.28,
            "sprint10": 2.1, "sprint20": 3.6,
        ])]
    }

    static var metrics: [MetricEntry] {
        [
            MetricEntry(json: ["id": 1, "recorded_at": "2026-08-15", "weight": 64.2,
                               "body_fat_perc": 22.4, "calm_pulse": 58,
                               "sys": 118, "dia": 74, "waist_circumference": 71]),
            MetricEntry(json: ["id": 2, "recorded_at": "2026-06-20", "weight": 66.1,
                               "body_fat_perc": 24.1, "calm_pulse": 62]),
        ]
    }

    static var reviews: [Review] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let calendar = Calendar.current
        let today = Date()

        func entry(_ id: Int, _ type: String, dayOffset: Int, duration: String,
                   hr: Double, kcal: Int, distance: Double? = nil) -> Review {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            var json: [String: Any] = [
                "id": id, "client_id": 12, "training_type": type,
                "duration": duration, "heart_rate": hr, "kcal": kcal,
                "date": formatter.string(from: day), "source": "app",
                "feedback_client": "Hat sich gut angefühlt.",
            ]
            if let distance { json["distance"] = distance }
            return Review(json: json)
        }

        return [
            entry(901, "Joggen", dayOffset: -2, duration: "00:48:12", hr: 148, kcal: 512, distance: 8200),
            entry(902, "Kraft", dayOffset: -5, duration: "01:05:00", hr: 121, kcal: 430),
            entry(903, "Rad", dayOffset: -9, duration: "01:52:30", hr: 139, kcal: 890, distance: 41300),
        ]
    }

    /// Ein plausibler Pulsverlauf: Aufwärmen, Belastung mit Intervallen, Auslauf.
    static var heartRateSeries: [HeartRatePoint] {
        (0..<180).map { index in
            let progress = Double(index) / 180
            let base: Double
            switch progress {
            case ..<0.15:  base = 95 + progress / 0.15 * 45
            case ..<0.85:  base = 140 + sin(progress * 22) * 18
            default:       base = 150 - (progress - 0.85) / 0.15 * 45
            }
            return HeartRatePoint(json: ["id": index, "value": base, "sort": index])
        }
    }

    static var plans: [TrainingPlan] {
        func row(_ exercise: String, _ sets: String, _ weight: String,
                 _ device: String = "", _ position: String = "") -> [String: Any] {
            ["exercise": exercise, "sets": sets, "weight": weight,
             "device": device, "position": position]
        }

        let values: [String: Any] = [
            "sonsomo": [
                row("Mobilisation Schulter", "2×15", "", "Band"),
                row("Aktivierung Rumpf", "3×30 s", "", "Matte"),
            ],
            "main": [
                row("Kniebeuge", "4×8", "60 kg", "Langhantel", "Rack 2"),
                row("Bankdrücken", "4×10", "45 kg", "Langhantel", "Bank 1"),
                row("Rudern vorgebeugt", "3×12", "35 kg", "Langhantel"),
            ],
            "core": [row("Plank", "3×45 s", "", "Matte")],
            "mobility": [row("Hüftöffner", "2×60 s", "", "Matte")],
            "dates": Array(repeating: "", count: 8),
        ]

        let encoded = String(data: (try? JSONSerialization.data(withJSONObject: values)) ?? Data(),
                             encoding: .utf8) ?? "{}"

        return [
            TrainingPlan(json: [
                "id": 501, "client_id": 12, "name": "Aufbau August",
                "status": "published", "created_at": "2026-08-03 09:00:00",
                "values": encoded,
            ]),
            TrainingPlan(json: [
                "id": 502, "client_id": 12, "name": "Regeneration",
                "status": "draft", "created_at": "2026-08-20 14:30:00",
                "values": encoded,
            ]),
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
