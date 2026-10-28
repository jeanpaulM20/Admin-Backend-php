import Foundation
import Network
import UIKit

/// Lädt aufgezeichnete Trainings als Batch hoch
/// (`POST /api/client/workouts/{clientId}` → Review + HF-Timeseries).
/// Schlägt der Upload vorübergehend fehl (offline, Server, Sitzung), landet
/// das Training in einer lokalen Warteschlange und wird nachgereicht
/// (App-Start, Rückkehr in den Vordergrund, Netz wieder da).
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

    /// Zählt nur endgültige Ablehnungen (4xx) — Netz- und Sitzungsfehler
    /// zählen nicht. Drei genügen, weil sich eine Ablehnung nicht von selbst
    /// erledigt und jeder Versuch den vollen Payload sendet.
    static let maxAttempts = 3

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
        // Kein JSON (z. B. Hotel-WLAN mit Anmeldeseite): vorübergehend
        guard let result else {
            throw APIError(statusCode: -2, message: "Antwort konnte nicht gelesen werden")
        }
        guard result["success"] as? Bool == true else {
            throw APIError(statusCode: -3, message: "Training konnte nicht gespeichert werden")
        }
        return (result["id"] as? Int) ?? Int("\(result["id"] ?? "")")
    }

    // MARK: - Fehlerart

    enum Failure: Equatable {
        /// Kein Netz, Timeout, Server 5xx/408/429, unlesbare Antwort
        case transient
        /// 401: Token abgelaufen — nach erneutem Login nachreichen
        case sessionExpired
        /// 403: kein Zugriff auf dieses Konto (Server prüft Mandant)
        case forbidden
        /// Übrige 4xx bzw. inhaltliche Ablehnung — erneutes Senden hilft nicht
        case rejected(String)
    }

    static func classify(_ error: Error) -> Failure {
        if error is URLError { return .transient }
        guard let api = error as? APIError else { return .transient }
        switch api.statusCode {
        case 401:                        return .sessionExpired
        case 403:                        return .forbidden
        case 408, 429:                   return .transient
        case 413:                        return .rejected("Training zu gross für den Upload")
        case 400..<500, -3:              return .rejected(api.message)
        default:                         return .transient   // 5xx, -1, -2
        }
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

    /// Dateischutz der Warteschlange: HF/GPS/Fotos sind Gesundheits- bzw.
    /// Standortdaten. UnlessOpen statt complete: Schreiben bei gesperrtem
    /// Bildschirm muss gehen, Lesen erst nach dem Entsperren.
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUnlessOpen]

    /// Gibt false zurück, wenn nichts eingereiht wurde (Demo/leeres Konto,
    /// Schreibfehler) — der Aufrufer darf dann den Snapshot nicht löschen.
    @discardableResult
    func queue(_ p: Payload) -> Bool {
        guard isQueueable(p.clientId) else { removePhotoFile(p.photoFile); return false }
        let url = queueDir.appendingPathComponent("\(UUID().uuidString).json")
        guard let data = try? JSONEncoder().encode(p),
              (try? data.write(to: url, options: Self.writeOptions)) != nil else { return false }
        return true
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
        try? data.write(to: queueDir.appendingPathComponent(name), options: Self.writeOptions)
        return name
    }

    /// Foto-only-Nachlieferung einreihen (Training bereits gespeichert).
    func queuePhoto(clientId: String, reviewId: Int, photoFile: String) {
        guard isQueueable(clientId) else { removePhotoFile(photoFile); return }
        let retry = PhotoRetry(clientId: clientId, reviewId: reviewId, photoFile: photoFile)
        let url = queueDir.appendingPathComponent("photo-\(UUID().uuidString).json")
        if let data = try? JSONEncoder().encode(retry) {
            try? data.write(to: url, options: Self.writeOptions)
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
    /// (Re-Login, Vordergrund, Netzwechsel) dieselbe Datei doppelt verarbeiten.
    @MainActor private static var retryInFlight = false

    /// Liegen gebliebene Trainings des angemeldeten Kontos nachreichen.
    /// Einträge anderer Konten bleiben liegen (Upload mit fremdem Token
    /// endet in 403). Fehlversuche zählen nur bei endgültigen Ablehnungen —
    /// eine Mehrtagestour ohne Netz darf nie zum Verwerfen führen.
    @MainActor
    func retryPending(clientId: String?) async {
        guard let clientId, isQueueable(clientId) else { return }
        // Gesperrtes Gerät: Dateien (UnlessOpen) sind nicht lesbar — ein
        // Lesefehler darf nie als „kaputt" gelten und gelöscht werden
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        guard !Self.retryInFlight else { return }
        Self.retryInFlight = true
        defer { Self.retryInFlight = false }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        var allReadable = true
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { allReadable = false; continue }

            // Reine Foto-Nachlieferung (Training war schon gespeichert)
            if file.lastPathComponent.hasPrefix("photo-") {
                if let retry = try? JSONDecoder().decode(PhotoRetry.self, from: data) {
                    guard retry.clientId == clientId else { continue }
                    if await retryPhoto(retry, jsonFile: file) == .stop { break }
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
            // Fremdes Konto: liegen lassen, bis es wieder angemeldet ist
            guard payload.clientId == clientId else { continue }
            if payload.attempts >= Self.maxAttempts {
                removePhotoFile(payload.photoFile)
                try? FileManager.default.removeItem(at: file)
                continue
            }

            let reviewId: Int?
            do {
                reviewId = try await upload(payload)
            } catch {
                switch Self.classify(error) {
                case .rejected:
                    // 413 (zu gross) wird nie angenommen → sofort aufgeben
                    let tooLarge = (error as? APIError)?.statusCode == 413
                    payload.attempts = tooLarge ? Self.maxAttempts : payload.attempts + 1
                    if let d = try? JSONEncoder().encode(payload) { try? d.write(to: file, options: Self.writeOptions) }
                    continue
                case .transient, .sessionExpired, .forbidden:
                    // Netz/Sitzung: alle weiteren scheitern gleich — später
                    return
                }
            }
            // Ohne id ist das Foto nicht zuordenbar: Eintrag behalten, das
            // Backend dedupliziert über clientRecordingId beim nächsten Versuch
            guard let rid = reviewId else {
                payload.attempts += 1
                if let d = try? JSONEncoder().encode(payload) { try? d.write(to: file, options: Self.writeOptions) }
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
        sweepIfSafe(allReadable: allReadable)
    }

    /// Verwaiste Fotos nur entfernen, wenn alle Einträge gelesen werden
    /// konnten — sonst gälte ein Foto eines unlesbaren Eintrags als verwaist.
    private func sweepIfSafe(allReadable: Bool) {
        if allReadable { sweepOrphanPhotos() }
    }

    /// JPEGs ohne referenzierende JSON entfernen (Schreibfehler, kaputte Einträge).
    private func sweepOrphanPhotos() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDir, includingPropertiesForKeys: nil)) ?? []
        var referenced = Set<String>()
        for f in files where f.pathExtension == "json" {
            guard let d = try? Data(contentsOf: f) else { return }   // unlesbar: nichts löschen
            if let p = try? JSONDecoder().decode(Payload.self, from: d), let n = p.photoFile { referenced.insert(n) }
            if let r = try? JSONDecoder().decode(PhotoRetry.self, from: d) { referenced.insert(r.photoFile) }
        }
        for f in files where f.pathExtension == "jpg" && !referenced.contains(f.lastPathComponent) {
            try? FileManager.default.removeItem(at: f)
        }
    }

    private enum RetryOutcome { case next, stop }

    private func retryPhoto(_ retry: PhotoRetry, jsonFile: URL) async -> RetryOutcome {
        guard retry.attempts < Self.maxAttempts else {
            try? FileManager.default.removeItem(at: jsonFile)
            removePhotoFile(retry.photoFile)
            return .next
        }
        guard let bytes = photoData(retry.photoFile) else { return .next }   // ggf. gesperrt: später
        guard let image = UIImage(data: bytes) else {
            try? FileManager.default.removeItem(at: jsonFile)
            removePhotoFile(retry.photoFile)
            return .next
        }
        do {
            try await WorkoutPhotoService.shared.upload(
                clientId: retry.clientId, reviewId: retry.reviewId, image: image)
            removePhotoFile(retry.photoFile)
            try? FileManager.default.removeItem(at: jsonFile)
            return .next
        } catch {
            guard case .rejected = Self.classify(error) else { return .stop }
            var next = retry; next.attempts += 1
            if let d = try? JSONEncoder().encode(next) { try? d.write(to: jsonFile, options: Self.writeOptions) }
            return .next
        }
    }
}

// MARK: - Nachreichen auslösen

/// Stösst `retryPending` an: beim Start, bei Rückkehr in den Vordergrund und
/// sobald das Netz zurückkommt. Entprellt (mehrere Auslöser in kurzer Folge
/// ergeben einen Lauf); parallele Läufe verhindert `retryInFlight`.
@MainActor
final class PendingUploadScheduler {
    static let shared = PendingUploadScheduler()
    private init() {}

    /// Liefert das aktuell angemeldete Konto (nil/Demo → kein Nachreichen).
    var clientIdProvider: @MainActor () -> String? = { nil }

    private var debounce: Task<Void, Never>?
    private var monitor: NWPathMonitor?
    private var wasOnline: Bool?
    /// Läuft gerade ein Nachreichen? Dann nicht abbrechen (ein halber
    /// Upload über Mobilfunk begänne sonst bei null), sondern danach
    /// genau einmal erneut laufen lassen.
    private var running = false
    private var rerunRequested = false

    /// Entprellt nur die Wartezeit — ein laufender Upload wird nie abgebrochen.
    func trigger(delay: Duration = .seconds(2)) {
        debounce?.cancel()
        debounce = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.startRun()
        }
    }

    private func startRun() {
        guard !running else { rerunRequested = true; return }
        running = true
        // Eigener Task, unabhängig vom Entprell-Task: ein späterer trigger()
        // bricht ihn nicht ab
        Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                self.rerunRequested = false
                await WorkoutUploadService.shared.retryPending(clientId: self.clientIdProvider())
            } while self.rerunRequested
            self.running = false
        }
    }

    /// Netzwechsel beobachten: offline → online löst ein Nachreichen aus.
    func startMonitoring() {
        guard monitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.wasOnline = online }
                if online, self.wasOnline == false { self.trigger(delay: .seconds(3)) }
            }
        }
        m.start(queue: DispatchQueue(label: "sihl.upload.path"))
        monitor = m
    }
}
