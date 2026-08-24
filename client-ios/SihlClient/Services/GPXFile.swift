import Foundation
import CoreLocation

/// GPX-Export/-Import (T4). Export schreibt einen `<trk>` mit einem
/// `<trkseg>` je Segment (deckt auch ungeordnete OSM-Relationen sauber ab);
/// Import liest `<trkpt>`-Punkte aus allen Segmenten.
enum GPXFile {

    // MARK: - Export

    /// Schreibt eine GPX-Datei in tmp und gibt die URL zurück (für ShareLink).
    static func write(name: String, segments: [[CLLocationCoordinate2D]],
                      elevations: [[Double?]] = []) -> URL? {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="SihlClient" xmlns="http://www.topografix.com/GPX/1/1">
        <trk><name>\(escape(name))</name>
        """
        for (s, seg) in segments.enumerated() {
            xml += "<trkseg>\n"
            for (i, c) in seg.enumerated() {
                let ele = (s < elevations.count && i < elevations[s].count) ? elevations[s][i] : nil
                if let ele {
                    xml += "<trkpt lat=\"\(c.latitude)\" lon=\"\(c.longitude)\"><ele>\(Int(ele))</ele></trkpt>\n"
                } else {
                    xml += "<trkpt lat=\"\(c.latitude)\" lon=\"\(c.longitude)\"/>\n"
                }
            }
            xml += "</trkseg>\n"
        }
        xml += "</trk>\n</gpx>\n"

        let safeName = name.replacingOccurrences(of: "[^A-Za-z0-9äöüÄÖÜ ._-]", with: "",
                                                 options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName.isEmpty ? "Tour" : safeName).gpx")
        guard (try? xml.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        return url
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Import

    /// Liest eine GPX-Datei und baut ein `TourDetail` (Distanz + Dauer werden
    /// berechnet; Aktivität heuristisch als Wandern).
    static func parse(url: URL) -> TourDetail? {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }

        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.parse()

        let segments = delegate.segments.filter { $0.count >= 2 }
        guard !segments.isEmpty else { return nil }
        let elevations = delegate.elevations

        var distanceM = 0.0
        var gain = 0.0
        for (s, seg) in segments.enumerated() {
            var lastEle: Double?
            for i in seg.indices {
                if i > 0 {
                    distanceM += CLLocation(latitude: seg[i - 1].latitude, longitude: seg[i - 1].longitude)
                        .distance(from: CLLocation(latitude: seg[i].latitude, longitude: seg[i].longitude))
                }
                if s < elevations.count, i < elevations[s].count, let e = elevations[s][i] {
                    if let last = lastEle, e - last >= 2 { gain += e - last; lastEle = e }
                    else if let last = lastEle, e - last <= -2 { lastEle = e }
                    else if lastEle == nil { lastEle = e }
                }
            }
        }
        let km = distanceM / 1000
        let climbH = gain / 400, horizH = km / 4.2
        let durationMin = Int((max(horizH, climbH) + min(horizH, climbH) / 2) * 60)

        return TourDetail(
            id: "gpx-\(url.lastPathComponent)",
            name: delegate.trackName ?? url.deletingPathExtension().lastPathComponent,
            activity: "hiking",
            description: "Importierte GPX-Datei",
            distanceKm: (km * 10).rounded() / 10,
            durationMin: durationMin,
            difficulty: km < 8 ? "Leicht" : (km < 16 ? "Mittel" : "Schwer"),
            elevationGain: gain > 0 ? Int(gain) : nil,
            segments: segments,
            elevations: elevations
        )
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var trackName: String?
        var segments: [[CLLocationCoordinate2D]] = []
        var elevations: [[Double?]] = []
        private var currentSeg: [CLLocationCoordinate2D] = []
        private var currentEles: [Double?] = []
        private var text = ""
        private var inName = false
        private var inEle = false
        private var pendingEle: Double?

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            switch name {
            case "trkseg":
                currentSeg = []; currentEles = []
            case "trkpt":
                pendingEle = nil
                if let lat = Double(attributes["lat"] ?? ""),
                   let lon = Double(attributes["lon"] ?? "") {
                    currentSeg.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    currentEles.append(nil)
                }
            case "ele":  inEle = true;  text = ""
            case "name": inName = true; text = ""
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inEle || inName { text += string }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                    qualifiedName: String?) {
            switch name {
            case "trkseg":
                if !currentSeg.isEmpty { segments.append(currentSeg); elevations.append(currentEles) }
            case "ele":
                inEle = false
                if !currentEles.isEmpty { currentEles[currentEles.count - 1] = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            case "name":
                inName = false
                if trackName == nil { trackName = text.trimmingCharacters(in: .whitespacesAndNewlines) }
            default: break
            }
        }
    }
}
