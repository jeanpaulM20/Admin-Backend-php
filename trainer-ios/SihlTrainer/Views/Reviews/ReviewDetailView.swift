import SwiftUI
import Charts

/// Eine Aufzeichnung im Detail: Kennzahlen, Belastung, Herzfrequenzverlauf.
/// Pendant zum Review-Detail aus `workout_feedback_screen.dart`.
struct ReviewDetailView: View {
    let review: Review
    @StateObject private var model: ReviewDetailViewModel

    init(review: Review, hrMax: Int, isPreview: Bool) {
        self.review = review
        _model = StateObject(wrappedValue: ReviewDetailViewModel(
            review: review, hrMax: hrMax, isPreview: isPreview
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                statTiles
                if let trimp = model.trimp {
                    trimpCard(trimp)
                }
                heartRateCard
                feedbackCard
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .navigationTitle(review.trainingType ?? "Aufzeichnung")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    // MARK: - Kennzahlen

    private var statTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: AppSpacing.stack) {
            if let duration = review.duration, !duration.isEmpty {
                StatTile(value: duration, label: "Dauer")
            }
            if let hr = review.heartRate, hr > 0 {
                StatTile(value: "\(Int(hr))", label: "Ø Herzfrequenz", accent: AppColor.brass)
            }
            if let kcal = review.kcal {
                StatTile(value: "\(kcal)", label: "Kalorien", accent: AppColor.brass)
            }
            if let distance = review.distance, distance > 0 {
                StatTile(value: String(format: "%.2f km", distance / 1000), label: "Distanz")
            }
            if let elevation = review.elevationGain {
                StatTile(value: "\(elevation) m", label: "Höhenmeter")
            }
            if let maxHr = model.maxHeartRate {
                StatTile(value: "\(Int(maxHr))", label: "Max. Herzfrequenz", accent: AppColor.brass)
            }
        }
    }

    /// Trainingsbelastung nach Edwards — derselbe Wert wie in der Client-App.
    private func trimpCard(_ trimp: Double) -> some View {
        Card {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trainingsbelastung")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    Text(Trimp.rating(trimp))
                        .font(.app(17, weight: .bold))
                        .foregroundStyle(Trimp.color(trimp))
                }
                Spacer(minLength: 0)
                Text("\(Int(trimp.rounded()))")
                    .font(.app(28, weight: .bold))
                    .foregroundStyle(Trimp.color(trimp))
            }
        }
    }

    // MARK: - Herzfrequenz

    @ViewBuilder private var heartRateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Herzfrequenz")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)

                if model.isLoading {
                    ProgressView().tint(AppColor.primary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if model.points.isEmpty {
                    Text("Für diese Aufzeichnung liegen keine Messwerte vor.")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                } else {
                    chart
                    zoneLegend
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(model.points) { point in
                if let value = point.value {
                    LineMark(
                        x: .value("Punkt", point.sort),
                        y: .value("Puls", value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(AppColor.cta)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
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
        .frame(height: 180)
    }

    /// Etwas Luft nach oben und unten, sonst klebt die Kurve am Rahmen.
    private var yDomain: ClosedRange<Double> {
        let values = model.points.compactMap(\.value)
        guard let min = values.min(), let max = values.max(), min < max else {
            return 40...200
        }
        return (min - 8)...(max + 8)
    }

    /// Zonen mit den Grenzen, die auch die Belastung verwendet.
    private var zoneLegend: some View {
        let zones: [(String, ClosedRange<Double>, Color)] = [
            ("Sehr leicht", 0...0.6, AppColor.zoneVeryLight),
            ("Leicht", 0.6...0.7, AppColor.zoneLight),
            ("Moderat", 0.7...0.8, AppColor.zoneModerate),
            ("Intensiv", 0.8...0.9, AppColor.zoneIntense),
            ("Maximal", 0.9...1.0, AppColor.zoneMax),
        ]
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(zones, id: \.0) { name, range, color in
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(name)
                        .font(.app(12))
                        .foregroundStyle(AppColor.text)
                    Spacer(minLength: 0)
                    Text("\(Int(Double(model.hrMax) * range.lowerBound))–\(Int(Double(model.hrMax) * range.upperBound)) bpm")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var feedbackCard: some View {
        let client = review.feedbackClient?.isEmpty == false ? review.feedbackClient : nil
        let trainer = review.feedbackTrainer?.isEmpty == false ? review.feedbackTrainer : nil
        if client != nil || trainer != nil {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Rückmeldungen")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    if let client {
                        labelled("Kunde", client)
                    }
                    if let trainer {
                        labelled("Trainer", trainer)
                    }
                }
            }
        }
    }

    private func labelled(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.app(11, weight: .semibold))
                .foregroundStyle(AppColor.brass)
            Text(text)
                .font(.app(14))
                .foregroundStyle(AppColor.text)
        }
    }
}
