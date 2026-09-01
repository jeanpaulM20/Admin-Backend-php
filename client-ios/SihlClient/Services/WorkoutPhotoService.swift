import Foundation
import UIKit

// MARK: - Modell

/// Ein Galerie-Eintrag: Foto plus die Werte der Trainingseinheit
/// (KONZEPT-TRAININGS-GALERIE.md, F1).
struct WorkoutPhoto: Identifiable, Hashable {
    let id: Int             // photoId
    let reviewId: Int
    let activity: String    // "Joggen", "Wandern", …
    let date: Date?
    let duration: String?   // "HH:mm:ss"
    let distanceMeters: Int?
    let elevationGain: Int?
    let avgHr: Int?

    init?(json: [String: Any]) {
        guard let id = Int("\(json["photoId"] ?? "")"),
              let reviewId = Int("\(json["reviewId"] ?? "")") else { return nil }
        self.id = id
        self.reviewId = reviewId
        self.activity = json["activity"] as? String ?? ""
        self.date = APIDate.parse("\(json["date"] ?? "")")
        self.duration = json["duration"] as? String
        self.distanceMeters = Int("\(json["distanceMeters"] ?? "")")
        self.elevationGain = Int("\(json["elevationGain"] ?? "")")
        self.avgHr = Int("\(json["avgHr"] ?? "")")
    }

    /// Passende Aufnahme-Aktivität, um dieselbe Einheit erneut zu starten.
    var workoutActivity: WorkoutActivity {
        WorkoutActivity(rawValue: activity) ?? .joggen
    }

    /// Startzeit „09:04" — nil, wenn nur ein Datum ohne echte Uhrzeit
    /// vorliegt (Mitternacht würde sonst „00:00" vortäuschen).
    var startTimeText: String? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        if (c.hour ?? 0) == 0, (c.minute ?? 0) == 0, (c.second ?? 0) == 0 { return nil }
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    var distanceText: String? {
        guard let m = distanceMeters, m > 0 else { return nil }
        return m >= 1000 ? String(format: "%.1f km", Double(m) / 1000) : "\(m) m"
    }

    /// Kurzform der Dauer: "46:12" statt "00:46:12".
    var durationText: String? {
        guard let d = duration else { return nil }
        let parts = d.split(separator: ":").map(String.init)
        guard parts.count == 3 else { return d }
        return parts[0] == "00" ? "\(parts[1]):\(parts[2])" : d
    }
}

// MARK: - Service

/// Fotos der Trainings-Galerie: hochladen, auflisten, Bilder laden.
/// Die Bilder liegen serverseitig (review_photo); geladene Bilder
/// werden im Arbeitsspeicher zwischengehalten.
actor WorkoutPhotoService {
    static let shared = WorkoutPhotoService()
    private var imageCache: [Int: UIImage] = [:]

    /// Foto zu einer Aufzeichnung hochladen (ersetzt ein vorhandenes).
    func upload(clientId: String, reviewId: Int, image: UIImage) async throws {
        guard let data = Self.prepare(image) else {
            throw APIError(statusCode: -4, message: "Bild konnte nicht verarbeitet werden")
        }
        _ = try await APIClient.shared.postJSONObject(
            "/api/client/workouts/\(clientId)/\(reviewId)/photo",
            body: ["image": data.base64EncodedString(), "mime": "image/jpeg"],
            timeout: 60)
    }

    /// Galerie-Einträge, optional auf eine Aktivität gefiltert.
    func list(clientId: String, activity: WorkoutActivity?) async throws -> [WorkoutPhoto] {
        var path = "/api/client/workouts/\(clientId)/photos"
        if let activity,
           let esc = activity.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?activity=\(esc)"
        }
        return try await APIClient.shared.getJSONArray(path, timeout: 30)
            .compactMap { WorkoutPhoto(json: $0) }
    }

    /// Bild laden (gecacht).
    func image(clientId: String, photoId: Int) async -> UIImage? {
        if let cached = imageCache[photoId] { return cached }
        guard let data = try? await APIClient.shared
            .get("/api/client/workouts/\(clientId)/photo/\(photoId)", timeout: 30),
              let image = UIImage(data: data) else { return nil }
        if imageCache.count > 60 { imageCache.removeAll() }
        imageCache[photoId] = image
        return image
    }

    func delete(clientId: String, photoId: Int) async throws {
        _ = try await APIClient.shared.delete("/api/client/workouts/\(clientId)/photo/\(photoId)")
        imageCache[photoId] = nil
    }

    // MARK: Intern

    /// Bereitet ein Foto fürs Reel-Format auf: 9:16 zugeschnitten,
    /// höchstens 1080×1920, als JPEG unter der Serverschwelle.
    ///
    /// Bewusst über `UIGraphicsImageRenderer` statt über `cgImage`:
    /// `draw(in:)` löst die EXIF-Drehung von selbst auf und funktioniert
    /// auch bei Bildern ohne direkten Pixelzugriff (bearbeitete Fotos,
    /// manche HEIC aus der Mediathek). Der frühere Weg fiel dort auf das
    /// ungeschnittene Original in voller Auflösung zurück — der Server
    /// wies es dann als „Bild zu gross" ab.
    nonisolated static func prepare(_ image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let ratio: CGFloat = 9.0 / 16.0
        let maxW: CGFloat = 1080, maxH: CGFloat = 1920

        // Zielrahmen im 9:16-Format, begrenzt auf 1080×1920
        var w = min(image.size.width, maxW)
        var h = w / ratio
        if h > maxH { h = maxH; w = h * ratio }
        let canvas = CGSize(width: w.rounded(), height: h.rounded())

        // Formatfüllend zeichnen, Überstand fällt an den Rändern weg
        let scale = max(canvas.width / image.size.width, canvas.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (canvas.width - drawn.width) / 2,
                             y: (canvas.height - drawn.height) / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1        // Punkte = Pixel; sonst wird das Bild 2–3× so gross
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }

        // Qualität senken, bis das Bild sicher unter die Serverschwelle passt
        for quality in [0.8, 0.65, 0.5, 0.35] as [CGFloat] {
            if let data = rendered.jpegData(compressionQuality: quality),
               data.count <= maxUploadBytes { return data }
        }
        return rendered.jpegData(compressionQuality: 0.3)
    }

    /// Der Server nimmt bis 3 MB an — mit Abstand, damit nichts knapp scheitert.
    private static let maxUploadBytes = 2_500_000
}
