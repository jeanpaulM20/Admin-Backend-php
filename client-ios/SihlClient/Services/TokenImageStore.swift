import Foundation
import ImageIO
import UIKit

// MARK: - TokenImageStore

/// Bild-Speicher für Token-geschützte Bilder (Übungsbilder).
///
/// - Ein Download je URL: gleichzeitige Anfragen teilen sich denselben
///   Ladevorgang. Verschwinden alle Wartenden (Kachel aus dem Bild
///   gescrollt), wird der Download abgebrochen.
/// - Zwei Grössen aus derselben Quelle: Vollbild (Vorschau, Zoom) und
///   Thumbnails in Pixelgrösse der Kachel — eine 72-pt-Kachel zeichnet
///   so kein 1024-px-Bitmap.
/// - Bilder werden abseits des Main Threads dekodiert
///   (`byPreparingForDisplay`, ImageIO-Thumbnail), damit das erste
///   Zeichnen nicht ruckelt.
/// - Begrenzt nach echten Bitmap-Kosten; NSCache räumt bei Speicherdruck
///   selbst auf. `removeAll()` beim Logout — keine Bilder über
///   Kontowechsel hinweg.
actor TokenImageStore {
    static let shared = TokenImageStore()

    /// Fertige Bilder je Schlüssel (`url` = Vollbild, `url#px` = Thumbnail).
    /// NSCache ist threadsicher — darum auch ohne Actor-Hop lesbar.
    // NSCache ist threadsicher, aber nicht als Sendable markiert
    private nonisolated(unsafe) let images: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 64 << 20   // 64 MB dekodierte Bitmaps
        c.countLimit = 150
        return c
    }()

    /// Rohdaten je URL — daraus entstehen weitere Grössen ohne neuen Download.
    private nonisolated(unsafe) let data: NSCache<NSString, NSData> = {
        let c = NSCache<NSString, NSData>()
        c.totalCostLimit = 24 << 20
        return c
    }()

    private struct Download {
        let id: UUID
        let task: Task<Data?, Never>
        var waiters: Int
    }
    private var downloads: [String: Download] = [:]

    // MARK: Lesen

    /// Schlüssel einer Grösse — `maxPixel == nil` heisst volle Grösse.
    nonisolated static func key(_ url: String, maxPixel: Int?) -> String {
        maxPixel.map { "\(url)#\($0)" } ?? url
    }

    /// Synchroner Blick in den Speicher — damit eine neu erzeugte Kachel
    /// ein schon geladenes Bild ohne Platzhalter-Frame zeigt.
    nonisolated func cached(_ url: String, maxPixel: Int? = nil) -> UIImage? {
        images.object(forKey: Self.key(url, maxPixel: maxPixel) as NSString)
    }

    /// Bild in der gewünschten Grösse — aus dem Speicher oder geladen.
    /// `nil` bei Fehler (kein Bild, kein Netz, 401) oder Abbruch; Fehler
    /// werden nicht gemerkt, der nächste Aufruf versucht es erneut.
    func image(for url: String, token: String?, maxPixel: Int? = nil) async -> UIImage? {
        let key = Self.key(url, maxPixel: maxPixel)
        if let hit = images.object(forKey: key as NSString) { return hit }
        guard let bytes = await bytes(for: url, token: token), !Task.isCancelled else { return nil }
        // Dekodieren ausserhalb des Actors — sonst stünden alle anderen
        // Anfragen hinter dieser Arbeit an
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decode(bytes, maxPixel: maxPixel)
        }.value
        guard let decoded else { return nil }
        images.setObject(decoded, forKey: key as NSString, cost: Self.cost(of: decoded))
        return decoded
    }

    /// Alles verwerfen (Logout).
    func removeAll() {
        images.removeAllObjects()
        data.removeAllObjects()
        for d in downloads.values { d.task.cancel() }
        downloads.removeAll()
    }

    // MARK: Laden

    private func bytes(for url: String, token: String?) async -> Data? {
        if let hit = data.object(forKey: url as NSString) { return hit as Data }

        let entry: Download
        if var running = downloads[url] {
            running.waiters += 1
            downloads[url] = running
            entry = running
        } else {
            let task = Task.detached(priority: .userInitiated) { await Self.fetch(url, token: token) }
            entry = Download(id: UUID(), task: task, waiters: 1)
            downloads[url] = entry
        }

        let result = await withTaskCancellationHandler {
            await entry.task.value
        } onCancel: {
            Task { await self.leave(url, id: entry.id) }
        }

        if Task.isCancelled { return nil }
        // Nur den eigenen Eintrag aufräumen — nach einem Abbruch kann unter
        // derselben URL schon ein neuer Download laufen
        if downloads[url]?.id == entry.id { downloads[url] = nil }
        if let result { data.setObject(result as NSData, forKey: url as NSString, cost: result.count) }
        return result
    }

    /// Ein Wartender ist weg — ist es der letzte, wird abgebrochen.
    private func leave(_ url: String, id: UUID) {
        guard var d = downloads[url], d.id == id else { return }
        d.waiters -= 1
        if d.waiters <= 0 {
            d.task.cancel()
            downloads[url] = nil
        } else {
            downloads[url] = d
        }
    }

    private static func fetch(_ urlString: String, token: String?) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        if let t = token, !t.isEmpty {
            request.setValue(t, forHTTPHeaderField: APIConfig.authHeader)
        }
        guard let (bytes, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              !bytes.isEmpty else { return nil }
        return bytes
    }

    // MARK: Dekodieren

    /// Vollbild: dekodiert und anzeigebereit. Thumbnail: per ImageIO direkt
    /// in Zielgrösse (ohne das volle Bitmap zu erzeugen). PNG und WebP.
    private static func decode(_ bytes: Data, maxPixel: Int?) -> UIImage? {
        guard let maxPixel else {
            return UIImage(data: bytes)?.preparingForDisplay()
        }
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}
