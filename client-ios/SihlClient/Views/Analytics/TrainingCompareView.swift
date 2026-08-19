import SwiftUI
import Charts

// MARK: - TrainingCompareView

/// Pendant zu `TrainingCompareScreen` — überlagert mehrere HR-Kurven in einem Chart.
struct TrainingCompareView: View {
    let reviews: [TrainingReview]
    @Environment(\.dismiss) private var dismiss

    // Farben für die einzelnen Linien (wie Flutter `_lineColors`)
    private static let lineColors: [Color] = [
        Color(red: 0.94, green: 0.33, blue: 0.31),   // #EF5350 rot
        Color(red: 0.26, green: 0.65, blue: 0.96),   // #42A5F5 blau
        Color(red: 0.40, green: 0.73, blue: 0.41),   // #66BB6A grün
        Color(red: 1.00, green: 0.44, blue: 0.26),   // #FF7043 orange
        Color(red: 0.67, green: 0.28, blue: 0.74),   // #AB47BC lila
    ]

    // Reviews die tatsächlich Chart-Daten haben
    private var withChart: [TrainingReview] { reviews.filter(\.hasChartData) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if withChart.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Legende
                            legendView

                            // Überlagerter Chart
                            overlayChart
                                .frame(height: 260)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 16)
                                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColor.muted.opacity(0.15), lineWidth: 1))

                            // Stat-Tabelle
                            statTable

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Vergleich")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }

    // MARK: - Legende

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(withChart.indices, id: \.self) { i in
                let review = withChart[i]
                let color  = Self.lineColors[i % Self.lineColors.count]
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 20, height: 3)
                    Text(review.trainingType)
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.text)
                    Text("·")
                        .foregroundStyle(AppColor.muted)
                    Text(review.formattedDate())
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Überlagerter Chart

    private var overlayChart: some View {
        Chart {
            ForEach(withChart.indices, id: \.self) { ri in
                let review = withChart[ri]
                let color  = Self.lineColors[ri % Self.lineColors.count]
                let sampled = downsample(review.chart, maxPoints: 300)
                ForEach(sampled.indices, id: \.self) { i in
                    LineMark(
                        x: .value("Index", i),
                        y: .value("BPM",   sampled[i].value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(by: .value("Training", "\(ri)"))
                }
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel().foregroundStyle(AppColor.muted)
                AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
            }
        }
    }

    // MARK: - Stat-Tabelle

    private var statTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kennzahlen")
                .font(.headline).foregroundStyle(AppColor.text)

            // Header
            HStack {
                Text("Training")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Max")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
                Text("Avg")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
                Text("Load")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 14)

            ForEach(withChart.indices, id: \.self) { i in
                let review = withChart[i]
                let color  = Self.lineColors[i % Self.lineColors.count]
                let trimp  = review.edwardsTrimp

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(review.trainingType)
                                .font(.caption.bold()).foregroundStyle(AppColor.text)
                            Text(review.formattedDate())
                                .font(.caption2).foregroundStyle(AppColor.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(review.hrMax.map { "\($0)" } ?? "-")
                        .font(.caption.bold()).foregroundStyle(.red)
                        .frame(width: 60, alignment: .trailing)
                    Text(review.hrAvg.map { "\($0)" } ?? "-")
                        .font(.caption.bold()).foregroundStyle(AppColor.primary)
                        .frame(width: 60, alignment: .trailing)
                    Text(trimp.map { "\(Int($0.rounded()))" } ?? "-")
                        .font(.caption.bold())
                        .foregroundStyle(trimp.map { TrainingReview.trimpColor($0) } ?? AppColor.muted)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColor.muted.opacity(0.1), lineWidth: 1))
            }
        }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash").font(.system(size: 48)).foregroundStyle(AppColor.muted)
            Text("Kein Vergleich möglich")
                .font(.headline).foregroundStyle(AppColor.text)
            Text("Die ausgewählten Trainings haben keine Herzfrequenz-Aufzeichnungen.")
                .font(.caption).foregroundStyle(AppColor.muted).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Zurück") { dismiss() }
                .buttonStyle(.bordered).tint(AppColor.primary)
        }
    }

    // MARK: - Downsampling

    private func downsample(_ pts: [HrPoint], maxPoints: Int) -> [HrPoint] {
        guard pts.count > maxPoints else { return pts }
        let step = pts.count / maxPoints
        return Swift.stride(from: 0, to: pts.count, by: max(step, 1)).map { pts[$0] }
    }
}
