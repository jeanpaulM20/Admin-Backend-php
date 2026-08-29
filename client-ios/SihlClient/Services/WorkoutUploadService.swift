import Foundation

/// Lädt aufgezeichnete Trainings als Batch hoch
/// (`POST /api/client/workouts/{clientId}` → Review + HF-Timeseries).
/// Schlägt der Upload fehl (offline), landet das Training in einer lokalen
/// Warteschlange und wird beim nächsten App-Start nachgereicht.
struct WorkoutUploadService {
    static let shared = WorkoutUploadService()
    private init() {}

    struct Payload: Codable {
        let clientId: String
        let trainingType: String
        let startedAt: Date
        let duration: String
        let samples: [HrSample]
        var track: [TrackPoint]? = nil
        var distanceMeters: Double? = nil
        var elevationGain: Double? = nil
    }

    private static let iso = ISO8601DateFormatter()

    /// HF-Serie fürs Backend auf ≤ 7'200 Punkte deckeln (1 Punkt/5 s bei
    /// 10 h). Der Gurt liefert ~1 Sample/s — bei Trekking-Längen würden
    /// sonst zehntausende Zeilen pro Training gespeichert, ohne dass die
    /// Auswertung feiner würde. Avg/Max sind davon unberührt (App-seitig
    /// aus der vollen Serie berechnet).
    static func thinned(_ samples: [HrSample]) -> [HrSample] {
        let cap = 7_200
        guard samples.count > cap else { return samples }
        let stride = (samples.count + cap - 1) / cap
        return samples.enumerated()
            .filter { $0.offset % stride == 0 }
            .map(\.element)
    }

    // MARK: - Upload

    /// Wirft bei Fehlschlag — Aufrufer entscheidet über Queue (`queue(_:)`).
    /// Rückgabe: die ID der angelegten Aufzeichnung (für das Galerie-Foto).
    @discardableResult
    func upload(_ p: Payload) async throws -> Int? {
        var body: [String: Any] = [
            "trainingType": p.trainingType,
            "startedAt": Self.iso.string(from: p.startedAt),
            "duration": p.duration,
            "hrSeries": Self.thinned(p.samples).map { ["t": Self.iso.string(from: $0.t), "v": $0.bpm] },
        ]
        if let track = p.track, !track.isEmpty {
            body["gpsTrack"] = track.map { pt -> [String: Any] in
                var row: [String: Any] = [
                    "t": Self.iso.string(from: pt.t),
                    "lat": pt.lat,
                    "lon": pt.lon,
                ]
                if let ele = pt.ele { row["ele"] = ele }
                if let acc = pt.acc { row["acc"] = acc }
                return row
            }
        }
        if let d = p.distanceMeters { body["distanceMeters"] = d }
        if let e = p.elevationGain  { body["elevationGain"]  = e }
        // Grosszügiger Timeout: mehrstündige Touren ergeben 1–3 MB Payload,
        // die auch über langsames Mobilfunknetz durchkommen sollen
        let result = try await APIClient.shared.postJSONObject(
            "/api/client/workouts/\(p.clientId)", body: body, timeout: 120)
        guard result?["success"] as? Bool == true else {
            throw APIError(statusCode: -3, message: "Training konnte nicht gespeichert werden")
        }
        return (result?["id"] as? Int) ?? Int("\(result?["id"] ?? "")")
    }

    // MARK: - Offline-Warteschlange

    private var queueDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-workouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func queue(_ p: Payload) {
        let url = queueDir.appendingPathComponent("\(UUID().uuidString).json")
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Nachreichen liegen gebliebener Trainings (Aufruf beim App-Start).
    func retryPending() async {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if (try? await upload(payload)) != nil {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
