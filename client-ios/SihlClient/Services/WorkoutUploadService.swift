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
    }

    private static let iso = ISO8601DateFormatter()

    // MARK: - Upload

    /// Wirft bei Fehlschlag — Aufrufer entscheidet über Queue (`queue(_:)`).
    func upload(_ p: Payload) async throws {
        let body: [String: Any] = [
            "trainingType": p.trainingType,
            "startedAt": Self.iso.string(from: p.startedAt),
            "duration": p.duration,
            "hrSeries": p.samples.map { ["t": Self.iso.string(from: $0.t), "v": $0.bpm] },
        ]
        let result = try await APIClient.shared.postJSONObject(
            "/api/client/workouts/\(p.clientId)", body: body)
        guard result?["success"] as? Bool == true else {
            throw APIError(statusCode: -3, message: "Training konnte nicht gespeichert werden")
        }
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
