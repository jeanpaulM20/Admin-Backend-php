import SwiftUI
import Charts

// MARK: - Detail-Sheets für geteilte Daten

// MARK: - DataDetailItem + Router

/// Hilfsstruct für `.sheet(item:)` — übergibt Kontext an das Detail-Sheet.
struct DataDetailItem: Identifiable {
    let id      = UUID()
    let message: ChatMessage
    let clientId: String
}

/// Pendant zu Flutter `_showDataPopup`: routet je Prefix auf das passende Detail-Sheet.
struct DataDetailRouterView: View {
    let item: DataDetailItem

    var body: some View {
        let text      = item.message.text
        let matchDate = extractChatDate(text)
        if text.hasPrefix("[TRAINING_REPORT]") || text.hasPrefix("[Aufzeichnung]") {
            ReviewDetailSheet(clientId: item.clientId, matchDate: matchDate)
        } else if text.hasPrefix("[Performance]") {
            PerformanceDetailSheet(clientId: item.clientId, matchDate: matchDate)
        } else {
            MetricDetailSheet(clientId: item.clientId)
        }
    }
}

// MARK: - Datums-Helfer (Pendant zu Flutter `_extractDate` / `_dateMatches`)

/// Extrahiert "dd.MM.yyyy" aus dem Nachrichtentext.
func extractChatDate(_ text: String) -> String? {
    guard let r = text.range(of: #"\d{2}\.\d{2}\.\d{4}"#, options: .regularExpression) else { return nil }
    return String(text[r])
}

/// Vergleicht ein rohes DB-Datum (ISO/`yyyy-MM-dd`) mit "dd.MM.yyyy".
func chatDateMatches(_ rawDbDate: String?, _ ddMMyyyy: String?) -> Bool {
    guard let raw = rawDbDate, let target = ddMMyyyy else { return false }
    if let d = parseChatAPIDate(raw) {
        return DateFormatter.chatDDMMYYYY.string(from: d) == target
    }
    return raw.contains(target)
}

func parseChatAPIDate(_ raw: String) -> Date? {
    DateFormatter.chatISO8601.date(from: raw)
        ?? DateFormatter.chatYYYYMMDDHHMMSS.date(from: raw)
        ?? DateFormatter.chatYYYYMMDD.date(from: raw)
}

/// Formatiert ein rohes API-Datum als "dd.MM.yyyy" (Flutter `_fmtDate`).
func fmtChatDate(_ raw: String?) -> String {
    guard let raw, !raw.isEmpty else { return "--" }
    guard let d = parseChatAPIDate(raw) else { return raw }
    return DateFormatter.chatDDMMYYYY.string(from: d)
}

/// Trainingstyp-Labels (Flutter `_trainingTypeLabel`).
func trainingTypeLabel(_ type: String?) -> String {
    let labels: [String: String] = [
        "cardio":       "Cardio",
        "endurance":    "Ausdauer",
        "strenght":     "Kraft",
        "speed":        "Schnelligkeit",
        "coordination": "Koordination",
        "free":         "Freies Training",
        "running":      "Laufen",
        "fitness":      "Fitness Level",
        "interval":     "Intervall",
    ]
    guard let type else { return "Training" }
    return labels[type] ?? type
}

/// Wert aus einem JSON-Dict als String; nil bei fehlend/leer.
func jsonString(_ v: Any?, fallback: String = "--") -> String {
    guard let v, !(v is NSNull) else { return fallback }
    return "\(v)"
}

/// Wert nur zurückgeben, wenn vorhanden und != 0 (Flutter: `value != null && value != 0`).
func nonZeroValue(_ v: Any?) -> String? {
    guard let v, !(v is NSNull) else { return nil }
    if let n = v as? NSNumber { return n.doubleValue == 0 ? nil : "\(n)" }
    let s = "\(v)"
    if s.isEmpty || s == "0" || s == "0.0" { return nil }
    return s
}

// MARK: - ReviewDetailSheet

/// Pendant zu Flutter `_ReviewDetailSheet`: HR-Chart, Edwards-TRIMP, HF-Zonen-Legende, Stat-Cards.
struct ReviewDetailSheet: View {
    let clientId:  String
    let matchDate: String?

    @State private var isLoading = true
    @State private var review:   TrainingReview? = nil
    @State private var rawDate:  String? = nil
    @State private var error:    String? = nil

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(AppColor.primary)
            } else if let error {
                Text(error).font(.callout).foregroundStyle(AppColor.muted)
            } else if let review {
                content(review)
            } else {
                Text("Nicht gefunden").font(.callout).foregroundStyle(AppColor.muted)
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private func load() async {
        do {
            let rows = try await ChatService.shared.getReviews(clientId: clientId)
            guard !rows.isEmpty else { isLoading = false; return }
            // Datensatz per Datum aus dem Nachrichtentext suchen (Flutter `_dateMatches`)
            let match = rows.first(where: { chatDateMatches($0["date"] as? String, matchDate) }) ?? rows[0]
            rawDate = match["date"] as? String
            review  = TrainingReview(json: match)
        } catch {
            self.error = "Daten konnten nicht geladen werden"
        }
        isLoading = false
    }

    private func content(_ r: TrainingReview) -> some View {
        let trimp      = r.edwardsTrimp
        let trimpValue = trimp.map { "\(Int($0.rounded()))" } ?? "--"
        let trimpColor = trimp.map { TrainingReview.trimpColor($0) } ?? AppColor.orange
        let trimpRating = trimp.map { TrainingReview.trimpRating($0) } ?? ""

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.control)
                            .fill(AppColor.red.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundStyle(AppColor.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trainingTypeLabel(r.trainingType.isEmpty ? nil : r.trainingType))
                            .font(.app(18, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Text(fmtChatDate(rawDate))
                            .font(.footnote)
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    if let avg = r.hrAvg {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.footnote)
                                .foregroundStyle(AppColor.red)
                            Text("\(avg) bpm")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.red)
                        }
                    }
                }

                // Stat-Cards (Dauer + Training Load)
                HStack(spacing: 10) {
                    reviewStatCard(icon: "timer", label: "Dauer",
                                   value: r.duration ?? "--", color: AppColor.blue)
                    reviewStatCard(icon: "dumbbell.fill",
                                   label: trimpRating.isEmpty ? "Training Load" : "Load · \(trimpRating)",
                                   value: trimpValue, color: trimpColor)
                }

                // HR-Chart + Zonen-Legende
                ReviewHrChartSection(points: r.chart, clientMaxHr: r.hrMax)
            }
            .padding(20)
        }
    }

    private func reviewStatCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.text)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// MARK: - ReviewHrChartSection

/// HR-Verlaufschart mit Max-Linie + HF-Zonen-Legende
/// (Pendant zu Flutter `_buildHrChart` / `_buildZoneLegend`).
/// Das Chart selbst kommt aus dem geteilten `HrLineChart` (Analytics).
struct ReviewHrChartSection: View {
    let clientMaxHr: Int?

    // Einmal beim Init berechnet statt mehrfach pro Body-Evaluation.
    private let validPoints: [HrPoint]
    private let minHr: Double
    private let maxHr: Double

    init(points: [HrPoint], clientMaxHr: Int?) {
        self.clientMaxHr = clientMaxHr
        let vp = points.filter { $0.value > 0 }
        self.validPoints = vp
        self.minHr = vp.map(\.value).min() ?? 0
        self.maxHr = vp.map(\.value).max() ?? 0
    }

    var body: some View {
        if validPoints.isEmpty {
            Text("Keine Herzfrequenz-Daten vorhanden")
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.footnote)
                        .foregroundStyle(AppColor.red)
                    Text("Herzfrequenz")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    Text("Min \(Int(minHr.rounded()))  /  Max \(Int(maxHr.rounded())) bpm")
                        .font(.caption2)
                        .foregroundStyle(AppColor.muted)
                }
                HrLineChart(chart: validPoints, showXAxis: false, maxHrLine: clientMaxHr)
                    .frame(height: 200)
                if let maxHr = clientMaxHr, maxHr > 0 {
                    zoneLegend(Double(maxHr))
                }
            }
        }
    }

    /// HF-Zonen-Legende (Flutter `_buildZoneLegend`).
    private func zoneLegend(_ maxHr: Double) -> some View {
        let zones: [(String, Color, Int)] = [
            ("Maximal",     AppColor.zoneMax,       Int((maxHr * 0.9).rounded())),
            ("Intensiv",    AppColor.zoneIntense,   Int((maxHr * 0.8).rounded())),
            ("Moderat",     AppColor.zoneModerate,  Int((maxHr * 0.7).rounded())),
            ("Leicht",      AppColor.zoneLight,     Int((maxHr * 0.6).rounded())),
            ("Sehr Leicht", AppColor.zoneVeryLight, Int((maxHr * 0.5).rounded())),
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)],
                         alignment: .leading, spacing: 4) {
            ForEach(zones, id: \.0) { zone in
                HStack(spacing: 4) {
                    Circle().fill(zone.1).frame(width: 8, height: 8)
                    Text("\(zone.0) (\(zone.2)+)")
                        .font(.app(10))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }
}

// MARK: - PerformanceDetailSheet

/// Pendant zu Flutter `_PerformanceDetailSheet`.
struct PerformanceDetailSheet: View {
    let clientId:  String
    let matchDate: String?

    @State private var isLoading = true
    @State private var test:     [String: Any]? = nil

    private struct PerfField: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let icon:  String
        let color: Color
    }

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(AppColor.primary)
            } else if let test {
                content(test)
            } else {
                Text("Nicht gefunden").font(.callout).foregroundStyle(AppColor.muted)
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private func load() async {
        do {
            let rows = try await ChatService.shared.getPerformanceTests(clientId: clientId)
            guard !rows.isEmpty else { isLoading = false; return }
            test = rows.first(where: { chatDateMatches($0["date"] as? String, matchDate) }) ?? rows.last
        } catch {}
        isLoading = false
    }

    private func content(_ t: [String: Any]) -> some View {
        let rawFields: [(label: String, raw: Any?, icon: String, color: Color)] = [
            ("Punkte",         t["points"],                "star.fill",                  AppColor.primary),
            ("Liegestuetz",    t["pushups"],               "dumbbell.fill",              AppColor.blue),
            ("Klimmzuege",     t["pullups"],               "dumbbell.fill",              AppColor.green),
            ("Unterarmstuetz", t["forearm_support"],       "timer",                      AppColor.orange),
            ("Seitstuetz",     t["side_support"],          "timer",                      AppColor.orange),
            ("Kniebeuge",      t["squat_on_wall"],         "figure.stand",               AppColor.blue),
            ("Rumpfbeuge",     t["trunk_bending"],         "figure.stand",               AppColor.green),
            ("Sensomotorik",   t["sensomotoric"],          "brain.head.profile",         AppColor.blue),
            ("Symmetrie",      t["symmetry"],              "scalemass",                  AppColor.green),
            ("Reaktion",       t["reaction"],              "bolt.fill",                  AppColor.orange),
            ("CMJ",            t["counter_movement_jump"], "arrow.up",                   AppColor.red),
            ("Tapping",        t["tapping"],               "hand.tap",                   AppColor.blue),
            ("Sprint 10m",     t["sprint_10"],             "figure.run",                 AppColor.green),
            ("Sprint 20m",     t["sprint_20"],             "figure.run",                 AppColor.green),
            ("Sprint 30m",     t["sprint_30"],             "figure.run",                 AppColor.green),
        ]
        let fields: [PerfField] = rawFields.compactMap { entry in
            nonZeroValue(entry.raw).map {
                PerfField(label: entry.label, value: $0, icon: entry.icon, color: entry.color)
            }
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.control)
                            .fill(AppColor.green.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundStyle(AppColor.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Performance Test")
                            .font(.app(18, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Text(fmtChatDate(t["date"] as? String))
                            .font(.footnote)
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(fields) { f in
                        HStack(spacing: 12) {
                            Image(systemName: f.icon)
                                .font(.callout)
                                .foregroundStyle(f.color)
                            Text(f.label)
                                .font(.callout)
                                .foregroundStyle(AppColor.text)
                            Spacer()
                            Text(f.value)
                                .font(.app(16, weight: .semibold))
                                .foregroundStyle(AppColor.text)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - MetricDetailSheet

/// Pendant zu Flutter `_MetricDetailSheet`: lädt `api/client/profile/{id}` direkt
/// (kein passender Service vorhanden — Rohwerte wie weight/bmi/body_fat/calm_pulse
/// sind in `ProfileData` nicht abgebildet).
struct MetricDetailSheet: View {
    let clientId: String

    @State private var isLoading = true
    @State private var metric:   [String: Any]? = nil

    private struct MetricField: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let icon:  String
        let color: Color
    }

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(AppColor.primary)
            } else if let metric {
                content(metric)
            } else {
                Text("Nicht gefunden").font(.callout).foregroundStyle(AppColor.muted)
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private func load() async {
        metric = try? await ProfileService().getProfileMetrics(clientId: clientId)
        isLoading = false
    }

    private func content(_ m: [String: Any]) -> some View {
        let rawFields: [(label: String, raw: Any?, icon: String, color: Color)] = [
            ("Gewicht",       m["weight"] ?? m["gewicht"],            "scalemass",   AppColor.blue),
            ("BMI",           m["bmi"],                               "speedometer", AppColor.green),
            ("Koerperfett %", m["body_fat"] ?? m["body_fat_percent"], "drop.fill",   AppColor.orange),
            ("Ruhepuls",      m["calm_pulse"],                        "heart.fill",  AppColor.red),
        ]
        let fields: [MetricField] = rawFields.compactMap { entry in
            nonZeroValue(entry.raw).map {
                MetricField(label: entry.label, value: $0, icon: entry.icon, color: entry.color)
            }
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.control)
                            .fill(AppColor.blue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "scalemass")
                            .font(.title3)
                            .foregroundStyle(AppColor.blue)
                    }
                    Text("Koerperwerte")
                        .font(.app(18, weight: .semibold))
                        .foregroundStyle(AppColor.text)
                    Spacer()
                }

                if fields.isEmpty {
                    Text("Keine Messwerte vorhanden")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(fields) { f in
                            HStack(spacing: 12) {
                                Image(systemName: f.icon)
                                    .font(.callout)
                                    .foregroundStyle(f.color)
                                Text(f.label)
                                    .font(.callout)
                                    .foregroundStyle(AppColor.text)
                                Spacer()
                                Text(f.value)
                                    .font(.app(16, weight: .semibold))
                                    .foregroundStyle(AppColor.text)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColor.background, in: RoundedRectangle(cornerRadius: AppRadius.control))
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
