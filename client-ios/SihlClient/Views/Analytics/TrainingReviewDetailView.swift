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
    let chart:     [HrPoint]
    var lineWidth: Double = 2
    var color:     Color  = .red
    var showXAxis: Bool   = true

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
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis(showXAxis ? .automatic : .hidden)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel().foregroundStyle(AppColor.muted)
                AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
            }
        }
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
                    HrLineChart(chart: review.chart, lineWidth: 1.5)
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
