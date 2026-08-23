import SwiftUI
import Charts

// MARK: - PerformanceDetailView

/// Pendant zu `PerformanceDetailScreen` in Flutter — zeigt aktuellen/vorherigen Wert + Verlauf-Chart.
struct PerformanceDetailView: View {
    let item:         PerformanceItem
    let sectionTitle: String

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // ── Wertekarte ─────────────────────────────────────────────
                    valueCard

                    // ── Verlauf-Chart ──────────────────────────────────────────
                    if item.history.isEmpty {
                        noHistoryCard
                    } else {
                        historyChart
                        historyTable
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Wertekarte

    private var valueCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Aktueller Wert")
                    .font(.caption).foregroundStyle(AppColor.muted)
                Text(item.value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(AppColor.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Vorher")
                    .font(.caption).foregroundStyle(AppColor.muted)
                Text(item.previousValue)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
            }
            if !item.change.isEmpty && item.change != "0" {
                Text(item.change)
                    .font(.callout.bold())
                    .foregroundStyle(item.changeColor)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(item.changeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 16)
            }
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Verlauf Chart (Swift Charts)

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verlauf")
                .font(.headline).foregroundStyle(AppColor.text)

            Chart {
                ForEach(item.history.indices, id: \.self) { i in
                    let p = item.history[i]
                    LineMark(
                        x: .value("Datum", p.date),
                        y: .value("Wert",  p.value)
                    )
                    .foregroundStyle(AppColor.primary)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Datum", p.date),
                        yStart: .value("Base", chartMinY),
                        yEnd:   .value("Wert", p.value)
                    )
                    .foregroundStyle(AppColor.primary.opacity(0.08))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Datum", p.date),
                        y: .value("Wert",  p.value)
                    )
                    .foregroundStyle(AppColor.primary)
                    .symbolSize(36)
                }
            }
            .chartYScale(domain: chartMinY...chartMaxY)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 2)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                        .foregroundStyle(AppColor.muted)
                    AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisValueLabel().foregroundStyle(AppColor.muted)
                    AxisGridLine().foregroundStyle(AppColor.muted.opacity(0.15))
                }
            }
            .frame(height: 200)
            .padding(AppSpacing.card)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Verlauf Tabelle

    private var historyTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Messwerte")
                .font(.headline).foregroundStyle(AppColor.text)

            ForEach(item.history.reversed(), id: \.date) { p in
                HStack {
                    Text(p.date, format: .dateTime.day().month().year())
                        .font(.callout).foregroundStyle(AppColor.muted)
                    Spacer()
                    Text("\(p.value.formatted(.number.precision(.fractionLength(1))))\(p.unit.isEmpty ? "" : " \(p.unit)")")
                        .font(.callout.bold()).foregroundStyle(AppColor.text)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(AppColor.muted.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private var noHistoryCard: some View {
        Text("Kein Verlauf vorhanden")
            .font(.callout).foregroundStyle(AppColor.muted)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.card)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Chart helpers

    private var chartMinY: Double {
        guard !item.history.isEmpty else { return 0 }
        let min = item.history.map(\.value).min()!
        let max = item.history.map(\.value).max()!
        let range = max - min
        return range == 0 ? min - 5 : min - range * 0.1
    }

    private var chartMaxY: Double {
        guard !item.history.isEmpty else { return 100 }
        let max = item.history.map(\.value).max()!
        let min = item.history.map(\.value).min()!
        let range = max - min
        return range == 0 ? max + 5 : max + range * 0.1
    }
}
