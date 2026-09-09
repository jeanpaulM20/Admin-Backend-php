import Foundation
import UIKit

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
        /// Optionales Trainingsfoto: Dateiname der beigelegten JPEG in der
        /// Warteschlange. So überlebt das Foto Offline-Speicherung und App-Kill.
        var photoFile: String? = nil
    }

    /// Wartender Foto-Upload für den Fall, dass das Training online gespeichert
    /// wurde (reviewId bekannt), der Foto-Upload aber scheiterte.
    struct PhotoRetry: Codable {
        let clientId: String
        let reviewId: Int
        let photoFile: String
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

    /// Foto-JPEG in die Warteschlange legen, gibt den Dateinamen zurück.
    func stashPhoto(_ data: Data) -> String {
        let name = "\(UUID().uuidString).jpg"
        try? data.write(to: queueDir.appendingPathComponent(name), options: .atomic)
        return name
    }

    /// Foto-only-Nachlieferung einreihen (Training bereits gespeichert).
    func queuePhoto(clientId: String, reviewId: Int, photoFile: String) {
        let retry = PhotoRetry(clientId: clientId, reviewId: reviewId, photoFile: photoFile)
        let url = queueDir.appendingPathComponent("photo-\(UUID().uuidString).json")
        if let data = try? JSONEncoder().encode(retry) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func photoData(_ name: String) -> Data? {
        try? Data(contentsOf: queueDir.appendingPathComponent(name))
    }
    private func removePhotoFile(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: queueDir.appendingPathComponent(name))
    }

    /// Nachreichen liegen gebliebener Trainings (Aufruf beim App-Start).
    func retryPending() async {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            let data = (try? Data(contentsOf: file)) ?? Data()

            // Reine Foto-Nachlieferung (Training war schon gespeichert)
            if file.lastPathComponent.hasPrefix("photo-") {
                if let retry = try? JSONDecoder().decode(PhotoRetry.self, from: data) {
                    await retryPhoto(retry, jsonFile: file)
                } else {
                    try? FileManager.default.removeItem(at: file)
                }
                continue
            }

            // Vollständiges Training (ggf. mit beigelegtem Foto)
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            let reviewId: Int?
            do {
                reviewId = try await upload(payload)
            } catch {
                continue  // offline o. Ä. — bleibt für den nächsten Start liegen
            }

            // Training ist hochgeladen. Beigelegtes Foto nachreichen.
            if let name = payload.photoFile {
                if let rid = reviewId, let bytes = photoData(name),
                   let image = UIImage(data: bytes) {
                    do {
                        try await WorkoutPhotoService.shared.upload(
                            clientId: payload.clientId, reviewId: rid, image: image)
                        removePhotoFile(name)
                    } catch {
                        // Foto scheiterte: als Foto-only-Nachlieferung behalten
                        queuePhoto(clientId: payload.clientId, reviewId: rid, photoFile: name)
                    }
                } else {
                    // Kein reviewId oder JPEG kaputt — nicht zuordenbar
                    removePhotoFile(name)
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func retryPhoto(_ retry: PhotoRetry, jsonFile: URL) async {
        guard let bytes = photoData(retry.photoFile), let image = UIImage(data: bytes) else {
            try? FileManager.default.removeItem(at: jsonFile)
            removePhotoFile(retry.photoFile)
            return
        }
        do {
            try await WorkoutPhotoService.shared.upload(
                clientId: retry.clientId, reviewId: retry.reviewId, image: image)
            removePhotoFile(retry.photoFile)
            try? FileManager.default.removeItem(at: jsonFile)
        } catch {
            // bleibt liegen, nächster App-Start versucht es erneut
        }
    }
}
