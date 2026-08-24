import SwiftUI
import Charts
import MapKit

// MARK: - TrainingReviewDetailView

/// Pendant zu `TrainingReviewDetailScreen` — Stat-Karten + HR-Verlaufschart;
/// bei App-Aufzeichnungen mit GPS zusätzlich Route + Höhenprofil.
struct TrainingReviewDetailView: View {
    @Environment(AuthViewModel.self) private var auth
    let review: TrainingReview

    @State private var showFullscreen = false
    @State private var track: [GeoPoint] = []

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // ── Stat-Karten (Max HF | Avg HF | Training Load) ──────────
                    statRow

                    // ── Outdoor-Stats (nur mit GPS-Daten) ─────────────────────
                    if review.distance != nil || review.elevationGain != nil {
                        outdoorStatRow
                    }

                    if let dur = review.duration {
                        Text("Dauer: \(dur)")
                            .font(.callout).foregroundStyle(AppColor.muted)
                    }

                    // ── Route + Höhenprofil (lazy geladen) ────────────────────
                    if track.count >= 2 {
                        routeCard
                        if track.contains(where: { $0.ele != nil }) {
                            elevationCard
                        }
                    }

                    // ── HR-Chart ───────────────────────────────────────────────
                    hrChartCard

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .task {
            // Track nur für App-Aufzeichnungen abfragen; leer = keine Karte
            guard let clientId = auth.clientId else { return }
            track = (try? await PerformanceService.shared.getTrack(
                clientId: clientId, reviewId: review.id)) ?? []
        }
        .navigationTitle(review.trainingType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Titel + Datum als Untertitel (wie Flutter AppBar, training_review_screen.dart:62-70)
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(review.trainingType)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(review.formattedDate())
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .sheet(isPresented: $showFullscreen) {
            FullscreenHrChart(review: review)
        }
    }

    // MARK: - Stat-Karten

    private var statRow: some View {
        HStack(spacing: 10) {
            StatCard(label: "Max HF",
                     value: review.hrMax.map { "\($0)" } ?? "-",
                     unit: "bpm", color: .red)
            StatCard(label: "Avg HF",
                     value: review.hrAvg.map { "\($0)" } ?? "-",
                     unit: "bpm", color: AppColor.primary)
            TrainingLoadCard(trimp: review.edwardsTrimp)
        }
    }

    // MARK: - Outdoor-Stats

    private var outdoorStatRow: some View {
        HStack(spacing: 10) {
            if let d = review.distance {
                StatCard(label: "Distanz",
                         value: d >= 1000 ? String(format: "%.2f", d / 1000) : "\(Int(d))",
                         unit: d >= 1000 ? "km" : "m", color: AppColor.text)
            }
            if let e = review.elevationGain {
                StatCard(label: "Höhenmeter", value: "\(e)", unit: "m", color: AppColor.text)
            }
        }
    }

    // MARK: - Route

    private var displayCoordinates: [CLLocationCoordinate2D] {
        let coords = track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        guard coords.count > 600 else { return coords }
        let stride = coords.count / 500
        return coords.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Route")
                .font(.callout.bold()).foregroundStyle(AppColor.text)
                .padding(.horizontal, AppSpacing.card).padding(.top, AppSpacing.card).padding(.bottom, 12)
            Map {
                MapPolyline(coordinates: displayCoordinates)
                    .stroke(AppColor.track, lineWidth: 4)
            }
            .frame(height: 220)
            .allowsHitTesting(false)
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Höhenprofil

    /// (Distanz [km], Höhe [m]) — kumuliert über den Track, auf ≤300 Punkte reduziert.
    private var elevationProfile: [(x: Double, ele: Double)] {
        var result: [(Double, Double)] = []
        var cum = 0.0
        var last: GeoPoint?
        for p in track {
            if let prev = last {
                let a = CLLocation(latitude: prev.lat, longitude: prev.lon)
                let b = CLLocation(latitude: p.lat, longitude: p.lon)
                cum += b.distance(from: a)
            }
            last = p
            if let ele = p.ele { result.append((cum / 1000, ele)) }
        }
        guard result.count > 300 else { return result }
        let stride = result.count / 300
        return result.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    private var elevationCard: some View {
        let profile = elevationProfile
        return VStack(alignment: .leading, spacing: 12) {
            Text("Höhenprofil")
                .font(.callout.bold()).foregroundStyle(AppColor.text)
            Chart {
                ForEach(profile.indices, id: \.self) { i in
                    let p = profile[i]
                    LineMark(x: .value("km", p.x), y: .value("m", p.ele))
                        .foregroundStyle(AppColor.primary)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("km", p.x),
                             yStart: .value("Base", profile.map(\.ele).min() ?? 0),
                             yEnd: .value("m", p.ele))
                        .foregroundStyle(
                            LinearGradient(colors: [AppColor.primary.opacity(0.2), AppColor.primary.opacity(0)],
                                           startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let km = value.as(Double.self) {
                            Text(String(format: "%.1f km", km))
                                .font(.system(size: 9)).foregroundStyle(AppColor.muted)
                        }
                    }
                    AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisValueLabel().foregroundStyle(AppColor.muted)
                    AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
                }
            }
            .frame(height: 140)
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    // MARK: - HR Chart

    private var hrChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Herzfrequenz-Verlauf (bpm)")
                    .font(.callout.bold()).foregroundStyle(AppColor.text)
                Spacer()
                if review.hasChartData {
                    Button {
                        showFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.callout)
                            .padding(6)
                            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.card).padding(.top, AppSpacing.card).padding(.bottom, 12)

            if review.hasChartData {
                HrLineChart(chart: review.chart, lineWidth: 2)
                    .frame(height: 200)
                    .padding(.horizontal, 8).padding(.bottom, 12)
            } else {
                Text("Keine HF-Kurvendaten vorhanden")
                    .font(.callout).foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - StatCard

struct StatCard: View {
    let label: String
    let value: String
    let unit:  String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2).foregroundStyle(AppColor.muted)
            Text(label)
                .font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - TrainingLoadCard

private struct TrainingLoadCard: View {
    let trimp: Double?

    var body: some View {
        let color  = trimp.map { TrainingReview.trimpColor($0) }  ?? AppColor.muted
        let rating = trimp.map { TrainingReview.trimpRating($0) } ?? ""
        let value  = trimp.map { "\($0.rounded().formatted())" }  ?? "--"

        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
            Text("Load")
                .font(.caption2).foregroundStyle(AppColor.muted)
            if !rating.isEmpty {
                Text(rating)
                    .font(.caption2.bold()).foregroundStyle(color)
            } else {
                Spacer(minLength: 14)
            }
            Text("Training Load")
                .font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - HrLineChart (wiederverwendbar für Detail + Compare)

/// Zeichnet eine HR-Kurve mit Swift Charts.
/// Downsampling auf maximal 500 Punkte für Performance.
struct HrLineChart: View {
    let chart:       [HrPoint]
    var lineWidth:   Double = 2
    var color:       Color  = AppColor.red
    var showXAxis:   Bool   = true
    var showTooltip: Bool   = false
    /// Gestrichelte Max-HF-Referenzlinie (z.B. Chat-Review-Sheet); erweitert die Y-Domain.
    var maxHrLine:   Int?   = nil

    @State private var selection: (index: Int, point: HrPoint)?

    // Einmal beim Init berechnet — als computed properties liefen Downsampling
    // und Min/Max sonst mehrfach pro Body-Evaluation bzw. pro Drag-Event.
    private let sampled:       [(index: Int, point: HrPoint)]
    private let minY:          Double
    private let maxY:          Double
    private let xLabelIndices: [Int]

    init(chart: [HrPoint], lineWidth: Double = 2, color: Color = AppColor.red,
         showXAxis: Bool = true, showTooltip: Bool = false, maxHrLine: Int? = nil) {
        self.chart       = chart
        self.lineWidth   = lineWidth
        self.color       = color
        self.showXAxis   = showXAxis
        self.showTooltip = showTooltip
        self.maxHrLine   = maxHrLine

        // Downsampling auf maximal 500 Punkte
        let maxPts = 500
        let sampled: [(index: Int, point: HrPoint)]
        if chart.count > maxPts {
            let stride = max(chart.count / maxPts, 1)
            sampled = Swift.stride(from: 0, to: chart.count, by: stride).map { ($0, chart[$0]) }
        } else {
            sampled = chart.enumerated().map { ($0.offset, $0.element) }
        }
        self.sampled = sampled

        let vals = sampled.map(\.point.value)
        let lower = (vals.min() ?? 60) - 5
        // Max-Linie in die Domain einbeziehen; lower+10 verhindert eine
        // invertierte Domain (Crash) bei pathologischen Messwerten.
        let upper = Swift.max((vals.max() ?? 180) + 5,
                              Double(maxHrLine ?? 0) + 10,
                              lower + 10)
        self.minY = lower
        self.maxY = upper

        // Uhrzeit-Labels bei 0 / 25 / 50 / 75 / 100 % der Kurve — auf die
        // tatsächlich geplotteten (gesampelten) Indizes gesnappt, sonst läge
        // das Endlabel außerhalb der Daten-Domain und würde nicht gerendert.
        let idxs = sampled.map(\.index)
        if idxs.count >= 2 {
            let n = idxs.count
            self.xLabelIndices = Array(Set([idxs[0], idxs[n / 4], idxs[n / 2],
                                            idxs[(n * 3) / 4], idxs[n - 1]])).sorted()
        } else {
            self.xLabelIndices = []
        }
    }

    var body: some View {
        Chart {
            ForEach(sampled, id: \.index) { item in
                LineMark(
                    x: .value("Index", item.index),
                    y: .value("BPM",   item.point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: lineWidth))

                AreaMark(
                    x: .value("Index", item.index),
                    yStart: .value("Base", minY),
                    yEnd:   .value("BPM",  item.point.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.15), color.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
            }

            // Max-HF-Referenzlinie (Chat-Review-Sheet)
            if let maxHr = maxHrLine, maxHr > 0 {
                RuleMark(y: .value("Max", Double(maxHr)))
                    .foregroundStyle(AppColor.zoneMax)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Max")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColor.zoneMax)
                    }
            }

            // Tooltip-Indikator: gestrichelte Linie + Punkt (wie Flutter :196-200)
            if showTooltip, let sel = selection {
                RuleMark(x: .value("Index", sel.index))
                    .foregroundStyle(color.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Index", sel.index),
                    y: .value("BPM",   sel.point.value)
                )
                .symbolSize(90)
                .foregroundStyle(color)
                .annotation(position: .top, spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                    tooltipLabel(sel.point)
                }
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: showXAxis ? xLabelIndices : []) { value in
                AxisValueLabel {
                    if let idx = value.as(Int.self), idx < chart.count {
                        Text(Self.timeLabel(chart[idx].time))
                            .font(.system(size: 9))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel().foregroundStyle(AppColor.muted)
                AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
            }
        }
        .chartOverlay { proxy in
            if showTooltip {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = drag.location.x - geo[plotFrame].origin.x
                                    guard let raw: Double = proxy.value(atX: x) else { return }
                                    // Nächstgelegenen (gesampelten) Punkt suchen
                                    selection = sampled.min {
                                        abs(Double($0.index) - raw) < abs(Double($1.index) - raw)
                                    }
                                }
                                .onEnded { _ in selection = nil }
                        )
                }
            }
        }
    }

    /// Zeitstempel (ISO/`HH:mm:ss`) → kompaktes "HH:mm"-Label.
    static func timeLabel(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        guard let d = APIDate.parse(raw) else { return raw }
        return Self.hhmm.string(from: d)
    }
    private static let hhmm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Tooltip-Inhalt: bpm + Uhrzeit (wie Flutter :187-194).
    private func tooltipLabel(_ p: HrPoint) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(p.value)) bpm")
            if let t = Self.timeLabel(p.time) as String?, !t.isEmpty {
                Text(t)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.border, lineWidth: 1))
    }
}

// MARK: - FullscreenHrChart Sheet

/// Großer HR-Chart in einem Sheet (Ersatz für Flutter's Landscape-Vollbildmodus).
private struct FullscreenHrChart: View {
    let review: TrainingReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        if let max = review.hrMax {
                            chipStat("Max", "\(max) bpm", .red)
                        }
                        if let avg = review.hrAvg {
                            chipStat("Avg", "\(avg) bpm", AppColor.primary)
                        }
                        if let dur = review.duration {
                            chipStat("Dauer", dur, AppColor.muted)
                        }
                    }
                    HrLineChart(chart: review.chart, lineWidth: 1.5, showTooltip: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                }
                .padding(16)
            }
            .navigationTitle("Herzfrequenz-Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
    }

    private func chipStat(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption).foregroundStyle(AppColor.muted)
            Text(value)
                .font(.caption.bold()).foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}
