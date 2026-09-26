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

    private struct Sample { let km: Double; let ele: Double }

    /// Mindestens zwei Höhenwerte, sonst gibt es nichts zu zeichnen.
    static func hasProfile(_ elevations: [[Double?]]) -> Bool {
        var n = 0
        for seg in elevations { for e in seg where e != nil { n += 1; if n >= 2 { return true } } }
        return false
    }

    private var samples: [Sample] {
        var out: [Sample] = []
        var km = 0.0
        var prev: CLLocation?
        for s in segments.indices {
            for i in segments[s].indices {
                let c = segments[s][i]
                let loc = CLLocation(latitude: c.latitude, longitude: c.longitude)
                if let prev { km += loc.distance(from: prev) / 1000 }
                prev = loc
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
