import SwiftUI
import Charts

// MARK: - Intensitätsrad und Kreis-Ansichten

// MARK: - Intensität (gemeinsame Helfer)

/// Farbe analog zu Flutter `_intensityColor`: ≤3 grün, ≤6 orange, >6 rot.
func intensityColor(_ v: Int) -> Color {
    if v <= 3 { return AppColor.green }
    if v <= 6 { return AppColor.orange }
    return AppColor.red
}

// MARK: - CircleGroupView

/// Pendant zu `_buildCircleGroup` in `chat_screen.dart`.
/// Aufeinanderfolgende Trainingskreis-Einträge werden als Summenkarte gezeigt;
/// Tap öffnet das Kachel-Grid (`_showCirclesExpanded`), Kachel-Tap das
/// Intensitätsrad (`_showCircleDetail`).
struct CircleGroupView: View {
    let messages: [ChatMessage]

    @State private var showExpanded  = false
    @State private var pendingDetail: Int? = nil
    @State private var detailValue:   CircleDetailValue? = nil

    /// Intensitätswerte: Zahl direkt aus dem Nachrichtentext (Flutter: `int.tryParse(c.text) ?? 0`).
    private var values: [Int] {
        messages.map { Int($0.text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
    }

    private var avg: Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }
    private var maxVal: Int { values.max() ?? 0 }

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button { showExpanded = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(intensityColor(Int(avg.rounded())).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "dumbbell.fill")
                            .font(.footnote)
                            .foregroundStyle(intensityColor(Int(avg.rounded())))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(messages.count) Trainingseinheiten")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppColor.text)
                        Text("Intensitaet: Ø \(String(format: "%.1f", avg))/10 · Max \(maxVal)/10")
                            .font(.caption2)
                            .foregroundStyle(AppColor.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.primary.opacity(0.24), lineWidth: 0.5)
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, 6)
        .sheet(isPresented: $showExpanded, onDismiss: {
            if let v = pendingDetail {
                pendingDetail = nil
                detailValue   = CircleDetailValue(value: v)
            }
        }) {
            CirclesExpandedSheet(values: values) { v in
                pendingDetail = v
                showExpanded  = false
            }
        }
        .sheet(item: $detailValue) { d in
            CircleDetailSheet(value: d.value)
        }
    }
}

struct CircleDetailValue: Identifiable {
    let id = UUID()
    let value: Int
}

// MARK: - CirclesExpandedSheet

/// Pendant zu Flutter `_showCirclesExpanded`: Kachel-Grid aller Circles.
struct CirclesExpandedSheet: View {
    let values:   [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.callout)
                        .foregroundStyle(AppColor.primary)
                    Text("Trainingsintensitaeten (\(values.count))")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 60), spacing: 8)],
                              alignment: .leading, spacing: 8) {
                        ForEach(values.indices, id: \.self) { i in
                            let val = values[i]
                            Button { onSelect(val) } label: {
                                VStack(spacing: 0) {
                                    Text("\(val)")
                                        .font(.app(18, weight: .bold))
                                        .foregroundStyle(intensityColor(val))
                                    Text("/10")
                                        .font(.app(10))
                                        .foregroundStyle(intensityColor(val).opacity(0.6))
                                }
                                .frame(width: 60, height: 60)
                                .background(intensityColor(val).opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: AppRadius.control))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.control)
                                        .stroke(intensityColor(val).opacity(0.31), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - CircleDetailSheet (Intensitätsrad)

/// Pendant zu Flutter `_showCircleDetail` + `_WheelSectorPainter`:
/// 10-Sektoren-Rad, gefüllt bis Intensitätswert, Rest gedimmt.
struct CircleDetailSheet: View {
    let value: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Trainingsintensitaet")
                    .font(.callout)
                    .foregroundStyle(AppColor.text)

                ZStack {
                    ForEach(0..<10, id: \.self) { i in
                        WheelSectorShape(sectorCount: 10, sectorIndex: i)
                            .fill(sectorColor(index: i, isActive: (i + 1) <= value))
                    }
                    Circle()
                        .fill(AppColor.background)
                        .frame(width: 72, height: 72)
                    Text("\(value)/10")
                        .font(.app(22, weight: .bold))
                        .foregroundStyle(AppColor.text)
                }
                .frame(width: 240, height: 240)

                Button("Schließen") { dismiss() }
                    .font(.callout)
                    .foregroundStyle(AppColor.primary)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Aktiv: Verlauf Grün → Dunkelrot je Sektor-Index (wie Flutter `Color.lerp`);
    /// inaktiv: Border-Farbe (gedimmt).
    private func sectorColor(index: Int, isActive: Bool) -> Color {
        guard isActive else { return AppColor.border }
        let t = Double(index) / 9.0
        return lerpColor(AppColor.green, AppColor.red, t)
    }

    private func lerpColor(_ a: Color, _ b: Color, _ t: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(min(max(t, 0), 1))
        return Color(.sRGB,
                     red:     Double(r1 + (r2 - r1) * f),
                     green:   Double(g1 + (g2 - g1) * f),
                     blue:    Double(b1 + (b2 - b1) * f),
                     opacity: Double(a1 + (a2 - a1) * f))
    }
}

/// SwiftUI-Port von Flutter `_WheelSectorPainter`: ein ringförmiger Sektor.
struct WheelSectorShape: Shape {
    let sectorCount: Int
    let sectorIndex: Int

    func path(in rect: CGRect) -> Path {
        let center      = CGPoint(x: rect.midX, y: rect.midY)
        let radius      = min(rect.width, rect.height) / 2 - 4
        let innerRadius = radius * 0.35
        let gapAngle    = 0.04
        let sweepAngle  = (2 * Double.pi / Double(sectorCount)) - gapAngle
        let startAngle  = -Double.pi / 2
                        + Double(sectorIndex) * (2 * Double.pi / Double(sectorCount))
                        + gapAngle / 2

        var p = Path()
        p.move(to: point(center, innerRadius, startAngle))
        p.addLine(to: point(center, radius, startAngle))
        p.addArc(center: center, radius: radius,
                 startAngle: .radians(startAngle),
                 endAngle:   .radians(startAngle + sweepAngle),
                 clockwise:  false)
        p.addLine(to: point(center, innerRadius, startAngle + sweepAngle))
        p.addArc(center: center, radius: innerRadius,
                 startAngle: .radians(startAngle + sweepAngle),
                 endAngle:   .radians(startAngle),
                 clockwise:  true)
        p.closeSubpath()
        return p
    }

    private func point(_ c: CGPoint, _ r: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
    }
}
