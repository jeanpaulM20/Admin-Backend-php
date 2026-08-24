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
                            chartCard

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
                    Spacer()
                    // Max-HF in bpm (wie Flutter training_compare_screen.dart:111-115)
                    if let hrMax = review.hrMax {
                        Text("\(hrMax) bpm")
                            .font(.caption.bold())
                            .foregroundStyle(color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Überlagerter Chart

    /// Chart-Karte mit Titel + X-Achsen-Hinweis (wie Flutter training_compare_screen.dart:136-149).
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Herzfrequenz-Verlauf (bpm)")
                .font(.callout.bold())
                .foregroundStyle(AppColor.text)
                .padding(.horizontal, AppSpacing.card)
                .padding(.top, AppSpacing.card)

            Text("X-Achse: Trainingsverlauf in %")
                .font(.app(10))
                .foregroundStyle(AppColor.muted)
                .padding(.horizontal, AppSpacing.card)
                .padding(.top, 4)
                .padding(.bottom, 14)

            overlayChart
                .frame(height: 260)
                .padding(.horizontal, 8)
                .padding(.bottom, AppSpacing.card)
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
            .stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    private var overlayChart: some View {
        Chart {
            ForEach(withChart.indices, id: \.self) { ri in
                let review  = withChart[ri]
                let sampled = downsample(review.chart, maxPoints: 300)
                let n       = sampled.count
                ForEach(sampled.indices, id: \.self) { i in
                    // X auf 0–100 % des Trainingsverlaufs normalisieren (wie Flutter :270-271)
                    LineMark(
                        x: .value("Verlauf", n > 1 ? Double(i) / Double(n - 1) * 100 : 50.0),
                        y: .value("BPM",     sampled[i].value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(by: .value("Training", "\(ri)"))
                }
            }
        }
        // Feste Farbzuordnung statt automatischer Palette (lineColors wie Flutter)
        .chartForegroundStyleScale(
            domain: withChart.indices.map { "\($0)" },
            range:  withChart.indices.map { Self.lineColors[$0 % Self.lineColors.count] }
        )
        .chartLegend(.hidden)
        .chartXScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [0.0, 50.0, 100.0]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.app(9))
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
                Text("Max HF")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
                Text("Avg HF")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
                Text("HRR")
                    .font(.caption).foregroundStyle(AppColor.muted)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 14)

            ForEach(withChart.indices, id: \.self) { i in
                let review = withChart[i]
                let color  = Self.lineColors[i % Self.lineColors.count]

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

                    // Werte-Spalten wie Flutter training_compare_screen.dart:203-208
                    Text(review.hrMax.map { "\($0)" } ?? "-")
                        .font(.caption.bold()).foregroundStyle(color)
                        .frame(width: 60, alignment: .trailing)
                    Text(review.hrAvg.map { "\($0)" } ?? "-")
                        .font(.caption.bold()).foregroundStyle(AppColor.text)
                        .frame(width: 60, alignment: .trailing)
                    Text(review.hrr.map { "\($0)" } ?? "-")
                        .font(.caption.bold()).foregroundStyle(AppColor.text)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(AppColor.muted.opacity(0.1), lineWidth: 1))
            }
        }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash").font(.app(48)).foregroundStyle(AppColor.muted)
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
