import SwiftUI
import Charts

/// Pendant zu `screens/training_analytics_screen.dart`: Kennzahlen und
/// Verteilungen über die Termine des Trainers. Alles wird aus den bereits
/// geladenen Terminen gerechnet — dafür gibt es keinen eigenen Endpunkt.
struct TrainingAnalyticsView: View {
    @EnvironmentObject private var store: TrainerStore
    @State private var range: TrainingStats.Range = .days90

    private var stats: TrainingStats {
        TrainingStats(trainings: store.trainings, range: range)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                rangePicker
                kpiGrid
                weeklyCard
                weekdayCard
                typeCard
                topClientsCard
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .navigationTitle("Auswertung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrainingStats.Range.allCases) { option in
                    FilterChip(title: option.title, isActive: range == option) {
                        range = option
                    }
                }
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  spacing: AppSpacing.stack) {
            StatTile(value: "\(stats.total)", label: "Termine")
            StatTile(value: "\(stats.uniqueClients)", label: "Kunden", accent: AppColor.brass)
            StatTile(value: "\(stats.cancelled)", label: "Absagen", accent: AppColor.red)
            StatTile(value: String(format: "%.0f %%", stats.cancelRate),
                     label: "Absagequote", accent: AppColor.red)
        }
    }

    private var weeklyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Auslastung der letzten 8 Wochen")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                Chart {
                    ForEach(stats.weeklyLoad, id: \.week) { entry in
                        BarMark(
                            x: .value("Woche", Self.weekFormatter.string(from: entry.week)),
                            y: .value("Termine", entry.count)
                        )
                        .foregroundStyle(AppColor.primary)
                        .cornerRadius(3)
                    }
                }
                .chartYAxis { axisMarks }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let text = value.as(String.self) {
                                Text(text)
                                    .font(.app(9))
                                    .foregroundStyle(AppColor.muted)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var weekdayCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text("Verteilung nach Wochentag")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                Chart {
                    ForEach(1...7, id: \.self) { weekday in
                        BarMark(
                            x: .value("Tag", TrainingStats.weekdayNames[weekday - 1]),
                            y: .value("Termine", stats.byWeekday[weekday] ?? 0)
                        )
                        .foregroundStyle(AppColor.brass)
                        .cornerRadius(3)
                    }
                }
                .chartYAxis { axisMarks }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let text = value.as(String.self) {
                                Text(text)
                                    .font(.app(10))
                                    .foregroundStyle(AppColor.muted)
                            }
                        }
                    }
                }
                .frame(height: 130)
            }
        }
    }

    /// Verteilung nach Trainingsart — der eigenständige Teil des
    /// Flutter-Screens `review_screen.dart`; die übrigen Auswertungen dort
    /// zeigen dieselben Zahlen wie diese Seite.
    @ViewBuilder private var typeCard: some View {
        let types = stats.byType
        if !types.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trainingsarten")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    ForEach(types, id: \.name) { entry in
                        HStack(spacing: 10) {
                            Text(entry.name)
                                .font(.app(14))
                                .foregroundStyle(AppColor.text)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            // Balkenanteil statt Tortenstück: im Dunkeln
                            // besser lesbar und ohne Legende verständlich.
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColor.primary)
                                    .frame(width: geometry.size.width * entry.share)
                            }
                            .frame(width: 90, height: 8)
                            Text("\(entry.count)")
                                .font(.app(13, weight: .semibold))
                                .foregroundStyle(AppColor.primary)
                                .frame(width: 26, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var topClientsCard: some View {
        if !stats.topClients.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Häufigste Kunden")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    ForEach(stats.topClients, id: \.name) { entry in
                        HStack(spacing: 10) {
                            Avatar(initials: entry.name.initials, size: 28)
                            Text(entry.name)
                                .font(.app(14))
                                .foregroundStyle(AppColor.text)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(entry.count)")
                                .font(.app(14, weight: .semibold))
                                .foregroundStyle(AppColor.primary)
                        }
                    }
                }
            }
        }
    }

    private var axisMarks: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(AppColor.border)
            AxisValueLabel {
                if let number = value.as(Int.self) {
                    Text("\(number)")
                        .font(.app(10))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }

    static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "d.M."
        return f
    }()
}
