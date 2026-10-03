import SwiftUI
import CoreLocation

// MARK: - ElevationProfileView

/// Höhenprofil einer Route: Distanz entlang der Strecke → Höhe.
/// `compact` zeichnet nur die Fläche (Planer-Panel), sonst zusätzlich
/// Höhen- und Distanzmarken (Tour-Detail).
struct ElevationProfileView: View {
    let segments: [[CLLocationCoordinate2D]]
    let elevations: [[Double?]]
    var compact = false
    /// Aktuelle Position entlang der Strecke (km) — Marker während der Aufzeichnung
    var progressKm: Double? = nil

    private struct Sample { let km: Double; let ele: Double }

    /// Mindestens zwei Höhenwerte, sonst gibt es nichts zu zeichnen.
    static func hasProfile(_ elevations: [[Double?]]) -> Bool {
        var n = 0
        for seg in elevations { for e in seg where e != nil { n += 1; if n >= 2 { return true } } }
        return false
    }

    /// Distanz entlang der Strecke (äquirektangulare Näherung — für
    /// Nachbarpunkte einer Route metergenau und ohne CLLocation-Objekte,
    /// damit die Neuberechnung bei jedem Panel-Update nichts kostet).
    private var samples: [Sample] {
        var out: [Sample] = []
        var km = 0.0
        var prev: CLLocationCoordinate2D?
        for s in segments.indices {
            for i in segments[s].indices {
                let c = segments[s][i]
                if let p = prev {
                    let dLat = (c.latitude - p.latitude) * 111.32
                    let dLon = (c.longitude - p.longitude) * 111.32 * cos(p.latitude * .pi / 180)
                    km += (dLat * dLat + dLon * dLon).squareRoot()
                }
                prev = c
                if s < elevations.count, i < elevations[s].count, let e = elevations[s][i] {
                    out.append(Sample(km: km, ele: e))
                }
            }
        }
        return out
    }

    var body: some View {
        let pts = samples
        if pts.count >= 2 {
            Canvas { ctx, size in
                let minE = pts.map(\.ele).min() ?? 0
                let maxE = pts.map(\.ele).max() ?? 0
                let range = max(maxE - minE, 20)          // flache Strecken nicht aufblasen
                let totalKm = max(pts.last?.km ?? 0, 0.01)
                let top: CGFloat = compact ? 4 : 16
                let bottom: CGFloat = compact ? 0 : 16
                let plotH = size.height - top - bottom
                func x(_ km: Double) -> CGFloat { CGFloat(km / totalKm) * size.width }
                func y(_ e: Double) -> CGFloat { top + plotH - CGFloat((e - minE) / range) * plotH }

                var line = Path()
                line.move(to: CGPoint(x: x(pts[0].km), y: y(pts[0].ele)))
                for p in pts.dropFirst() { line.addLine(to: CGPoint(x: x(p.km), y: y(p.ele))) }

                var area = line
                area.addLine(to: CGPoint(x: x(pts.last!.km), y: top + plotH))
                area.addLine(to: CGPoint(x: x(pts[0].km), y: top + plotH))
                area.closeSubpath()

                ctx.fill(area, with: .color(AppColor.track.opacity(0.22)))
                ctx.stroke(line, with: .color(AppColor.track), lineWidth: 1.5)

                // Position auf der Strecke: Linie + Punkt auf dem Profil
                if let progressKm {
                    let px = x(min(max(progressKm, 0), totalKm))
                    // Höhe an dieser Stelle (linear zwischen den Nachbarn)
                    let after = pts.firstIndex { $0.km >= progressKm } ?? pts.count - 1
                    let before = max(0, after - 1)
                    let span = max(pts[after].km - pts[before].km, 0.0001)
                    let t = min(max((progressKm - pts[before].km) / span, 0), 1)
                    let ele = pts[before].ele + (pts[after].ele - pts[before].ele) * t
                    var marker = Path()
                    marker.move(to: CGPoint(x: px, y: top))
                    marker.addLine(to: CGPoint(x: px, y: top + plotH))
                    ctx.stroke(marker, with: .color(AppColor.text.opacity(0.5)), lineWidth: 1)
                    let dot = Path(ellipseIn: CGRect(x: px - 4, y: y(ele) - 4, width: 8, height: 8))
                    ctx.fill(dot, with: .color(AppColor.green))
                    ctx.stroke(dot, with: .color(AppColor.white), lineWidth: 1.5)
                }

                guard !compact else { return }

                // Höhenmarken oben/unten, Distanzmarken am Fuss
                let label = { (t: String) in
                    Text(t).font(.app(10, weight: .medium)).foregroundStyle(AppColor.muted)
                }
                ctx.draw(label("\(Int(maxE.rounded())) m"), at: CGPoint(x: 0, y: 0), anchor: .topLeading)
                ctx.draw(label("\(Int(minE.rounded())) m"),
                         at: CGPoint(x: 0, y: top + plotH + 2), anchor: .topLeading)
                let step: Double = totalKm > 40 ? 10 : totalKm > 16 ? 5 : totalKm > 6 ? 2 : 1
                var km = step
                while km < totalKm - step * 0.35 {
                    var tick = Path()
                    tick.move(to: CGPoint(x: x(km), y: top + plotH))
                    tick.addLine(to: CGPoint(x: x(km), y: top + plotH + 4))
                    ctx.stroke(tick, with: .color(AppColor.border), lineWidth: 1)
                    ctx.draw(label("\(Int(km)) km"), at: CGPoint(x: x(km), y: top + plotH + 2), anchor: .top)
                    km += step
                }
                ctx.draw(label(TourFormat.distance(totalKm)),
                         at: CGPoint(x: size.width, y: top + plotH + 2), anchor: .topTrailing)
            }
            .accessibilityLabel("Höhenprofil")
        }
    }
}
