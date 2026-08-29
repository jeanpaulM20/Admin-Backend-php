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

    /// Auf 9:16 zuschneiden (Reel-Format), auf 1080×1920 begrenzen und
    /// als JPEG komprimieren — hält den Upload klein (~300 KB).
    nonisolated static func prepare(_ image: UIImage) -> Data? {
        // EXIF-Rotation zuerst auflösen: `cgImage` liefert die UNROTIERTEN
        // Pixel, während `size` bereits gedreht ist. Ein aus `size`
        // berechneter Crop trifft sonst die falsche Region oder ragt aus
        // dem Puffer — `cropping(to:)` gibt dann nil zurück und der
        // Fallback lud das Foto ungeschnitten in Originalgrösse hoch.
        let image = image.imageOrientation == .up ? image
            : UIGraphicsImageRenderer(size: image.size).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }

        let target: CGFloat = 9.0 / 16.0
        let size = image.size
        var crop = CGRect(origin: .zero, size: size)
        if size.width / size.height > target {          // zu breit → Seiten weg
            let w = size.height * target
            crop = CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        } else {                                         // zu hoch → oben/unten weg
            let h = size.width / target
            crop = CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        }
        guard let cg = image.cgImage?.cropping(to: crop) else { return image.jpegData(compressionQuality: 0.8) }
        let cropped = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)

        let maxSize = CGSize(width: 1080, height: 1920)
        let scale = min(maxSize.width / cropped.size.width, maxSize.height / cropped.size.height, 1)
        let final: UIImage
        if scale < 1 {
            let newSize = CGSize(width: cropped.size.width * scale, height: cropped.size.height * scale)
            final = UIGraphicsImageRenderer(size: newSize).image { _ in
                cropped.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            final = cropped
        }
        return final.jpegData(compressionQuality: 0.8)
    }
}
