import SwiftUI
import Charts

/// Zwei oder mehr Aufzeichnungen gegenüberstellen.
/// Pendant zu `screens/training_compare_screen.dart`.
struct ReviewCompareView: View {
    let reviews: [Review]
    let client: Client
    let isPreview: Bool

    @State private var series: [Int: [HeartRatePoint]] = [:]
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                chartCard
                summaryCard
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .navigationTitle("Vergleich")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var chartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Herzfrequenz im Vergleich")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)

                if isLoading {
                    ProgressView().tint(AppColor.primary)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if series.values.allSatisfy(\.isEmpty) {
                    Text("Keine der gewählten Aufzeichnungen hat Messwerte.")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                } else {
                    chart
                    legend
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                ForEach(series[review.id] ?? []) { point in
                    if let value = point.value {
                        LineMark(
                            // Anteil am Verlauf statt Messpunktnummer: die
                            // Aufzeichnungen sind unterschiedlich lang und
                            // wären sonst nicht vergleichbar.
                            x: .value("Verlauf", progress(of: point, in: review)),
                            y: .value("Puls", value),
                            // Ohne series verbindet Swift Charts die Punkte
                            // ALLER Aufzeichnungen zu einer einzigen Linie.
                            series: .value("Aufzeichnung", review.id)
                        )
                        .foregroundStyle(color(for: index))
                        .interpolationMethod(.monotone)
                    }
                }
            }
            if let max = client.maxHeartRate {
                RuleMark(y: .value("Max", max))
                    .foregroundStyle(AppColor.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            if let min = client.minHeartRate {
                RuleMark(y: .value("Min", min))
                    .foregroundStyle(AppColor.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppColor.border)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number))")
                            .font(.app(10))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                HStack(spacing: 8) {
                    Circle().fill(color(for: index)).frame(width: 8, height: 8)
                    Text(label(for: review))
                        .font(.app(12))
                        .foregroundStyle(AppColor.text)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kennzahlen")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Circle().fill(color(for: index)).frame(width: 7, height: 7)
                            Text(label(for: review))
                                .font(.app(14, weight: .semibold))
                                .foregroundStyle(AppColor.text)
                        }
                        Text(details(for: review))
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
    }

    /// Alle Kurven plus die Referenzlinien des Kunden im Bild behalten.
    private var yDomain: ClosedRange<Double> {
        let values = series.values.flatMap { $0.compactMap(\.value) }
        var lower = values.min() ?? 40
        var upper = values.max() ?? 200
        if let min = client.minHeartRate { lower = Swift.min(lower, Double(min)) }
        if let max = client.maxHeartRate { upper = Swift.max(upper, Double(max)) }
        guard lower < upper else { return 40...200 }
        return (lower - 8)...(upper + 8)
    }

    private func details(for review: Review) -> String {
        var parts: [String] = []
        if let duration = review.duration { parts.append(duration) }
        if let hr = review.heartRate, hr > 0 { parts.append("Ø \(Int(hr)) bpm") }
        if let kcal = review.kcal { parts.append("\(kcal) kcal") }
        if let distance = review.distance, distance > 0 {
            parts.append(String(format: "%.1f km", distance / 1000))
        }
        if let trimp = Trimp.edwards(series[review.id] ?? [],
                                     hrMax: client.maxHeartRate ?? 190,
                                     duration: review.duration) {
            parts.append("Belastung \(Int(trimp.rounded()))")
        }
        return parts.joined(separator: " · ")
    }

    private func label(for review: Review) -> String {
        let type = review.trainingType ?? "Aufzeichnung"
        guard let date = review.date else { return type }
        return "\(type) — \(ReviewFormatters.date.string(from: date))"
    }

    private func color(for index: Int) -> Color {
        AppColor.chartSeries[index % AppColor.chartSeries.count]
    }

    private func progress(of point: HeartRatePoint, in review: Review) -> Double {
        let points = series[review.id] ?? []
        guard points.count > 1, let last = points.last?.sort, last > 0 else { return 0 }
        return Double(point.sort) / Double(last)
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            // Zwei leicht verschobene Verläufe, damit der Vergleich etwas zeigt.
            for (index, review) in reviews.enumerated() {
                series[review.id] = PreviewData.heartRateSeries.map { point in
                    HeartRatePoint(json: [
                        "id": point.id,
                        "sort": point.sort,
                        "value": (point.value ?? 0) - Double(index) * 9,
                    ])
                }
            }
            return
        }
        #endif
        let service = ReviewService()
        await withTaskGroup(of: (Int, [HeartRatePoint]).self) { group in
            for review in reviews {
                group.addTask {
                    ((review.id), (try? await service.timeseries(reviewId: review.id)) ?? [])
                }
            }
            for await (id, points) in group {
                series[id] = points
            }
        }
    }
}
