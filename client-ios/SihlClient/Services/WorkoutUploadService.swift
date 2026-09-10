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
        /// Idempotenz-Schlüssel (UUID der Aufzeichnung): Backend legt bei
        /// erneutem Upload kein zweites Training an, sondern liefert die id.
        var clientRecordingId: String? = nil
        /// Fehlversuche beim Nachreichen — nach `maxAttempts` wird verworfen,
        /// sonst würde ein dauerhaft abgelehnter Eintrag bei jedem Start erneut
        /// hochgeladen (MB-Payloads, für immer).
        var attempts: Int = 0
    }

    /// Wartender Foto-Upload für den Fall, dass das Training online gespeichert
    /// wurde (reviewId bekannt), der Foto-Upload aber scheiterte.
    struct PhotoRetry: Codable {
        let clientId: String
        let reviewId: Int
        let photoFile: String
        var attempts: Int = 0
    }

    static let maxAttempts = 20

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
        if let rid = p.clientRecordingId { body["clientRecordingId"] = rid }
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
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var url = dir
            var rv = URLResourceValues(); rv.isExcludedFromBackup = true
            try? url.setResourceValues(rv)
        }
        return dir
    }

    /// Nur echte Konten kommen in die Warteschlange — ein Demo- oder leerer
    /// clientId scheitert am Server dauerhaft und würde ewig wiederholt.
    private func isQueueable(_ clientId: String) -> Bool {
        !clientId.isEmpty && clientId != "demo"
    }

    func queue(_ p: Payload) {
        guard isQueueable(p.clientId) else { removePhotoFile(p.photoFile); return }
        let url = queueDir.appendingPathComponent("\(UUID().uuidString).json")
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Wartende Foto-Nachlieferung für ein Review verwerfen — z. B. wenn der
    /// Nutzer inzwischen von Hand ein neueres Foto hochgeladen hat.
    func cancelPendingPhoto(reviewId: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("photo-") {
            guard let data = try? Data(contentsOf: file),
                  let retry = try? JSONDecoder().decode(PhotoRetry.self, from: data),
                  retry.reviewId == reviewId else { continue }
            removePhotoFile(retry.photoFile)
            try? FileManager.default.removeItem(at: file)
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
        guard isQueueable(clientId) else { removePhotoFile(photoFile); return }
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

    /// Läuft gerade ein Nachreichen? Verhindert, dass zwei überlappende Läufe
    /// (Re-Login, View-Neuaufbau) dieselbe Datei doppelt verarbeiten.
    @MainActor private static var retryInFlight = false

    /// Nachreichen liegen gebliebener Trainings (Aufruf beim App-Start).
    @MainActor
    func retryPending() async {
        guard !Self.retryInFlight else { return }
        Self.retryInFlight = true
        defer { Self.retryInFlight = false }

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
            guard var payload = try? JSONDecoder().decode(Payload.self, from: data) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if !isQueueable(payload.clientId) || payload.attempts >= Self.maxAttempts {
                removePhotoFile(payload.photoFile)
                try? FileManager.default.removeItem(at: file)
                continue
            }

            let reviewId: Int?
            do {
                reviewId = try await upload(payload)
            } catch {
                payload.attempts += 1
                if let d = try? JSONEncoder().encode(payload) { try? d.write(to: file, options: .atomic) }
                continue  // offline o. Ä. — nächster Start
            }
            // Ohne id ist das Foto nicht zuordenbar: Eintrag behalten, das
            // Backend dedupliziert über clientRecordingId beim nächsten Versuch
            guard let rid = reviewId else {
                payload.attempts += 1
                if let d = try? JSONEncoder().encode(payload) { try? d.write(to: file, options: .atomic) }
                continue
            }

            // Training ist hochgeladen. Beigelegtes Foto nachreichen.
            if let name = payload.photoFile {
                if let bytes = photoData(name), let image = UIImage(data: bytes) {
                    do {
                        try await WorkoutPhotoService.shared.upload(
                            clientId: payload.clientId, reviewId: rid, image: image)
                        removePhotoFile(name)
                    } catch {
                        queuePhoto(clientId: payload.clientId, reviewId: rid, photoFile: name)
                    }
                } else {
                    removePhotoFile(name)  // JPEG kaputt
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
        sweepOrphanPhotos()
    }

    /// JPEGs ohne referenzierende JSON entfernen (Schreibfehler, kaputte Einträge).
    private func sweepOrphanPhotos() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        var referenced = Set<String>()
        for f in files where f.pathExtension == "json" {
            guard let d = try? Data(contentsOf: f) else { continue }
            if let p = try? JSONDecoder().decode(Payload.self, from: d), let n = p.photoFile { referenced.insert(n) }
            if let r = try? JSONDecoder().decode(PhotoRetry.self, from: d) { referenced.insert(r.photoFile) }
        }
        for f in files where f.pathExtension == "jpg" && !referenced.contains(f.lastPathComponent) {
            try? FileManager.default.removeItem(at: f)
        }
    }

    private func retryPhoto(_ retry: PhotoRetry, jsonFile: URL) async {
        guard retry.attempts < Self.maxAttempts,
              let bytes = photoData(retry.photoFile), let image = UIImage(data: bytes) else {
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
            var next = retry; next.attempts += 1
            if let d = try? JSONEncoder().encode(next) { try? d.write(to: jsonFile, options: .atomic) }
        }
    }
}
