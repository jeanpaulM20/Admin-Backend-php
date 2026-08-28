import Foundation

/// Auswertung der Termine eines Trainers.
/// Pendant zu `_TrainingStats` aus `training_analytics_screen.dart` — dieselbe
/// Status-Einteilung, damit Flutter und iOS dieselben Zahlen zeigen.
struct TrainingStats {
    /// Betrachtungszeitraum.
    enum Range: String, CaseIterable, Identifiable {
        case days30, days90, days365, all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .days30:  return "30 Tage"
            case .days90:  return "90 Tage"
            case .days365: return "1 Jahr"
            case .all:     return "Alle"
            }
        }

        var days: Int? {
            switch self {
            case .days30:  return 30
            case .days90:  return 90
            case .days365: return 365
            case .all:     return nil
            }
        }
    }

    let total: Int
    let cancelled: Int
    let attended: Int
    let missed: Int
    let booked: Int
    let uniqueClients: Int
    /// Montag der Woche → Anzahl aktiver Termine, die letzten acht Wochen.
    let weeklyLoad: [(week: Date, count: Int)]
    /// 1 = Montag … 7 = Sonntag.
    let byWeekday: [Int: Int]
    let topClients: [(name: String, count: Int)]

    var cancelRate: Double { total > 0 ? Double(cancelled) / Double(total) * 100 : 0 }

    init(trainings: [Training], range: Range) {
        let calendar = Calendar.sihl
        let filtered: [Training]
        if let days = range.days,
           let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) {
            filtered = trainings.filter { ($0.startTime ?? .distantPast) >= cutoff }
        } else {
            filtered = trainings
        }

        total = filtered.count

        var cancelledCount = 0, attendedCount = 0, missedCount = 0, bookedCount = 0
        for training in filtered {
            let status = (training.status ?? "").lowercased()
            if training.isCancelled || status == "cancelled" || status == "canceled" {
                cancelledCount += 1
            } else if status == "attended" {
                attendedCount += 1
            } else if status == "missed" {
                missedCount += 1
            } else {
                bookedCount += 1
            }
        }
        cancelled = cancelledCount
        attended = attendedCount
        missed = missedCount
        booked = bookedCount

        // Kunden bevorzugt über die ID zählen; nur wo sie fehlt über den Namen.
        var clientKeys = Set<String>()
        for training in filtered {
            if let id = training.clientId, id > 0 {
                clientKeys.insert("id:\(id)")
            } else if let name = training.clientName, !name.isEmpty {
                clientKeys.insert("name:\(name)")
            }
        }
        uniqueClients = clientKeys.count

        /// Aktiv = weder abgesagt noch versäumt.
        func isActive(_ training: Training) -> Bool {
            let status = (training.status ?? "").lowercased()
            return !training.isCancelled && status != "cancelled"
                && status != "canceled" && status != "missed"
        }

        // Wochenlast der letzten acht Wochen, auch leere Wochen zeigen.
        let thisMonday = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        var weeks: [(week: Date, count: Int)] = []
        for offset in stride(from: 7, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisMonday),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let count = filtered.filter { training in
                guard let date = training.startTime, isActive(training) else { return false }
                return date >= start && date < end
            }.count
            weeks.append((week: start, count: count))
        }
        weeklyLoad = weeks

        var weekdays = Dictionary(uniqueKeysWithValues: (1...7).map { ($0, 0) })
        for training in filtered {
            guard let date = training.startTime, isActive(training) else { continue }
            // Calendar liefert 1 = Sonntag; hier soll 1 = Montag sein.
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
            weekdays[weekday, default: 0] += 1
        }
        byWeekday = weekdays

        var counts: [String: Int] = [:]
        for training in filtered where isActive(training) {
            let name = training.clientName ?? "Unbekannt"
            counts[name, default: 0] += 1
        }
        topClients = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }
    }

    static let weekdayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
}
