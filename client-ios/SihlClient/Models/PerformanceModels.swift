import Foundation
import SwiftUI

// MARK: - MetricHistoryPoint

/// Pendant zu `MetricHistoryPoint` in `models/metric_history.dart`.
struct MetricHistoryPoint {
    let date:  Date
    let value: Double
    let unit:  String

    init(json: [String: Any]) {
        self.date  = ISO8601DateFormatter().date(from: json["date"] as? String ?? "")
                   ?? DateFormatter.yyyyMMdd.date(from: json["date"] as? String ?? "")
                   ?? Date()
        self.value = Double("\(json["value"] ?? 0)") ?? 0
        self.unit  = json["unit"] as? String ?? ""
    }
}

// MARK: - PerformanceItem

/// Pendant zu `PerformanceItem` in `models/performance_section.dart`.
struct PerformanceItem: Hashable {
    let name:          String
    let value:         String
    let previousValue: String
    let change:        String
    let unit:          String
    let history:       [MetricHistoryPoint]

    init(json: [String: Any]) {
        self.name          = "\(json["key"]           ?? json["name"]          ?? "")"
        self.value         = "\(json["value"]         ?? "")"
        self.previousValue = "\(json["previousValue"] ?? "")"
        self.change        = "\(json["change"]        ?? "")"
        self.unit          = "\(json["unit"]          ?? "")"

        if let rawH = json["history"] as? [[String: Any]] {
            var pts: [MetricHistoryPoint] = []
            for h in rawH {
                let pt = MetricHistoryPoint(json: h)
                if pt.value != 0 { pts.append(pt) }
            }
            self.history = pts
        } else {
            self.history = []
        }
    }

    // Hashable: nach Name identifiziert
    static func == (l: Self, r: Self) -> Bool { l.name == r.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    /// Farbe für change-Wert (+ = grün, - = rot).
    var changeColor: Color {
        if change.hasPrefix("+") || change == "up"   { return .green }
        if change.hasPrefix("-") || change == "down"  { return .red   }
        return AppColor.muted
    }
}

// MARK: - PerformanceSection

/// Pendant zu `PerformanceSection` in `models/performance_section.dart`.
struct PerformanceSection: Identifiable {
    let id    = UUID()
    let title: String
    let items: [PerformanceItem]

    init(json: [String: Any]) {
        self.title = "\(json["section"] ?? json["title"] ?? "")"
        if let raw = json["data"] as? [[String: Any]] {
            self.items = raw.map { PerformanceItem(json: $0) }
        } else {
            self.items = []
        }
    }
}

// MARK: - HrPoint

/// Pendant zu `HrPoint` in `models/training_review.dart`.
struct HrPoint {
    let time:  String?
    let value: Double
}

// MARK: - TrainingReview

/// Pendant zu `TrainingReview` in `models/training_review.dart`.
struct TrainingReview: Identifiable, Hashable {
    let id:           String
    let date:         Date
    let trainingType: String
    let duration:     String?
    let hrMax:        Int?
    let hrAvg:        Int?
    let hrr:          Int?
    let hrv:          Double?
    let chart:        [HrPoint]

    init(json: [String: Any]) {
        self.id           = "\(json["id"] ?? UUID().uuidString)"
        let rawDate       = json["date"] as? String ?? ""
        self.date         = ISO8601DateFormatter().date(from: rawDate)
                          ?? DateFormatter.yyyyMMdd.date(from: rawDate)
                          ?? Date()
        self.trainingType = json["trainingType"] as? String ?? ""
        self.duration     = json["duration"] as? String
        self.hrMax        = Int("\(json["hrMax"] ?? "")")
        self.hrAvg        = Int("\(json["hrAvg"] ?? "")")
        self.hrr          = Int("\(json["hrr"]   ?? "")")
        self.hrv          = Double("\(json["hrv"] ?? "")")

        if let rawChart = json["chart"] as? [[String: Any]] {
            self.chart = rawChart.compactMap { p -> HrPoint? in
                guard let v = Double("\(p["v"] ?? "")") else { return nil }
                return HrPoint(time: p["t"] as? String, value: v)
            }
        } else {
            self.chart = []
        }
    }

    var hasChartData: Bool { chart.count >= 2 }

    // MARK: - Edwards TRIMP (portiert aus training_review.dart)

    /// Berechnet Edwards' TRIMP anhand der HR-Kurve und hrMax.
    var edwardsTrimp: Double? {
        guard hasChartData, let maxHR = hrMax, maxHR > 0 else { return nil }
        let valid = chart.filter { $0.value > 0 }
        guard !valid.isEmpty else { return nil }

        var intervalMin: Double = 0
        if valid.count >= 2, let t1 = valid.first?.time, let t2 = valid.last?.time,
           let dt1 = ISO8601DateFormatter().date(from: t1),
           let dt2 = ISO8601DateFormatter().date(from: t2) {
            let sec = dt2.timeIntervalSince(dt1)
            if sec > 0 { intervalMin = (sec / Double(valid.count - 1)) / 60 }
        }
        if intervalMin <= 0 {
            var totalMin: Double = 0
            if let dur = duration, !dur.isEmpty {
                let parts = dur.split(separator: ":").compactMap { Int($0) }
                if parts.count >= 2 {
                    totalMin = Double(parts[0]) * 60 + Double(parts[1])
                    if parts.count >= 3 { totalMin += Double(parts[2]) / 60 }
                }
            }
            if totalMin <= 0 { totalMin = Double(valid.count) / 60 }
            intervalMin = totalMin / Double(valid.count)
        }
        guard intervalMin > 0 else { return nil }

        var trimp: Double = 0
        for p in valid {
            let pct = p.value / Double(maxHR)
            let factor: Double
            if      pct >= 0.9 { factor = 5 }
            else if pct >= 0.8 { factor = 4 }
            else if pct >= 0.7 { factor = 3 }
            else if pct >= 0.6 { factor = 2 }
            else if pct >= 0.5 { factor = 1 }
            else               { factor = 0 }
            trimp += intervalMin * factor
        }
        return trimp > 0 ? trimp : nil
    }

    static func trimpRating(_ t: Double) -> String {
        if t < 50  { return "Leicht" }
        if t < 100 { return "Moderat" }
        if t < 150 { return "Mittel" }
        if t < 200 { return "Hart" }
        if t < 300 { return "Sehr Hart" }
        return "Extrem"
    }

    static func trimpColor(_ t: Double) -> Color {
        if t < 50  { return Color(hex: 0x4CAF50) }
        if t < 100 { return Color(hex: 0x8BC34A) }
        if t < 150 { return Color(hex: 0xFFC107) }
        if t < 200 { return Color(hex: 0xFF9800) }
        if t < 300 { return Color(hex: 0xFF5722) }
        return Color(hex: 0xF44336)
    }

    // Hashable
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Datumsformat-Hilfsmethode
    func formattedDate() -> String {
        let months = ["Jan","Feb","Mar","Apr","Mai","Jun","Jul","Aug","Sep","Okt","Nov","Dez"]
        let c = Calendar.current
        let m = c.component(.month, from: date) - 1
        let d = c.component(.day,   from: date)
        let y = c.component(.year,  from: date)
        return "\(d). \(months[m]) \(y)"
    }
}

// MARK: - PerformanceNavTarget (NavigationLink Wrapper)

/// Kapselt Item + Sektionsname für NavigationLink in SwiftUI.
struct PerformanceNavTarget: Hashable {
    let sectionTitle: String
    let item:         PerformanceItem
    static func == (l: Self, r: Self) -> Bool { l.sectionTitle == r.sectionTitle && l.item == r.item }
    func hash(into hasher: inout Hasher) { hasher.combine(sectionTitle); hasher.combine(item) }
}

// MARK: - DateFormatter helpers

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

// MARK: - Color hex init (intern)

extension Color {
    fileprivate init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
