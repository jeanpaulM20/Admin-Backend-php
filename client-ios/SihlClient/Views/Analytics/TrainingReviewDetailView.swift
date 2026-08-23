import SwiftUI
import Charts

// MARK: - TrainingReviewDetailView

/// Pendant zu `TrainingReviewDetailScreen` — Stat-Karten + HR-Verlaufschart.
struct TrainingReviewDetailView: View {
    let review: TrainingReview

    @State private var showFullscreen = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // ── Stat-Karten (Max HF | Avg HF | Training Load) ──────────
                    statRow

                    if let dur = review.duration {
                        Text("Dauer: \(dur)")
                            .font(.callout).foregroundStyle(AppColor.muted)
                    }

                    // ── HR-Chart ───────────────────────────────────────────────
                    hrChartCard

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
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
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

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
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
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
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
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
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
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

    @State private var selection: (index: Int, point: HrPoint)?

    // Downsampled version
    private var sampled: [(index: Int, point: HrPoint)] {
        let maxPts = 500
        guard chart.count > maxPts else {
            return chart.enumerated().map { ($0.offset, $0.element) }
        }
        let stride = chart.count / maxPts
        return Swift.stride(from: 0, to: chart.count, by: max(stride, 1))
            .map { ($0, chart[$0]) }
    }

    private var minY: Double {
        let vals = sampled.map(\.point.value)
        return (vals.min() ?? 60) - 5
    }
    private var maxY: Double {
        let vals = sampled.map(\.point.value)
        return (vals.max() ?? 180) + 5
    }

    /// Uhrzeit-Labels bei 0 / 25 / 50 / 75 / 100 % der Kurve
    /// (wie Flutter training_review_screen.dart:208-217).
    private var xLabelIndices: [Int] {
        let n = chart.count
        guard n >= 2 else { return [] }
        return Array(Set([0, n / 4, n / 2, (n * 3) / 4, n - 1])).sorted()
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
                        Text(chart[idx].time ?? "")
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

    /// Tooltip-Inhalt: bpm + Uhrzeit (wie Flutter :187-194).
    private func tooltipLabel(_ p: HrPoint) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(p.value)) bpm")
            if let t = p.time, !t.isEmpty {
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
