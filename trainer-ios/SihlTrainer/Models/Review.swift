import Foundation
import SwiftUI

/// Eine Trainingsaufzeichnung. Pendant zu `models/review.dart`.
struct Review: Identifiable, Equatable {
    let id: Int
    let duration: String?
    let kcal: Int?
    let heartRate: Double?
    let trainingType: String?
    let speed: Double?
    let distance: Double?
    let elevationGain: Int?
    let feedbackClient: String?
    let feedbackTrainer: String?
    let source: String?
    /// Datum der App-Aufzeichnung bzw. des gebuchten Trainings.
    let date: Date?

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        duration = JSON.string(json, "duration")
        kcal = JSON.intNonZero(json, "kcal")
        heartRate = JSON.double(json, "heart_rate", "heartRate")
        trainingType = JSON.string(json, "training_type", "trainingType", "type")
        speed = JSON.double(json, "speed")
        distance = JSON.double(json, "distance")
        elevationGain = JSON.intNonZero(json, "elevation_gain", "elevationGain")
        feedbackClient = JSON.string(json, "feedback_client", "feedbackClient")
        feedbackTrainer = JSON.string(json, "feedback_trainer", "feedbackTrainer")
        source = JSON.string(json, "source")

        // Gebuchte Trainings tragen das Datum in der verknüpften Relation,
        // App-Aufzeichnungen direkt in `date`.
        let training = json["training"] as? [String: Any]
        if let direct = JSON.date(JSON.string(json, "date")) {
            date = direct
        } else if let training {
            date = JSON.date(day: JSON.string(training, "date"),
                             time: JSON.string(training, "starttime", "time_from"))
        } else {
            date = nil
        }
    }

    /// "01:12:30" → 72 Minuten. Auch "72:30" (mm:ss) kommt vor.
    var durationMinutes: Double? {
        guard let duration else { return nil }
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        if parts.count >= 3 {
            return Double(parts[0]) * 60 + Double(parts[1]) + Double(parts[2]) / 60
        }
        return Double(parts[0]) + Double(parts[1]) / 60
    }
}

/// Ein Herzfrequenz-Messpunkt.
struct HeartRatePoint: Identifiable, Equatable {
    let id: Int
    let timestamp: Date?
    let value: Double?
    let sort: Int

    init(json: [String: Any]) {
        id = JSON.int(json, "id") ?? 0
        timestamp = JSON.date(JSON.string(json, "timestamp"))
        value = JSON.double(json, "value")
        sort = JSON.int(json, "sort") ?? 0
    }
}

/// Trainingsbelastung nach Edwards: Zeit-in-Zone × Zonenfaktor.
/// Portiert aus `Review.edwardsTrimp` — dieselben Zonengrenzen und
/// dieselbe Intervall-Herleitung, damit Trainer- und Client-App
/// denselben Wert zeigen.
enum Trimp {

    static func edwards(_ points: [HeartRatePoint], hrMax: Int,
                        duration: String? = nil) -> Double? {
        guard !points.isEmpty, hrMax > 0 else { return nil }
        let valid = points
            .sorted { $0.sort < $1.sort }
            .filter { ($0.value ?? 0) > 0 }
        guard !valid.isEmpty else { return nil }

        var intervalMinutes = 0.0

        // Zuerst die echten Zeitstempel.
        if valid.count >= 2, let first = valid.first?.timestamp, let last = valid.last?.timestamp {
            let seconds = last.timeIntervalSince(first)
            if seconds > 0 {
                intervalMinutes = (seconds / Double(valid.count - 1)) / 60
            }
        }

        // Sonst aus der Dauer, sonst grob geschätzt (ein Punkt je Sekunde).
        if intervalMinutes <= 0 {
            var totalMinutes = 0.0
            if let duration {
                let parts = duration.split(separator: ":").compactMap { Int($0) }
                if parts.count >= 2 {
                    let seconds = parts.count >= 3 ? Double(parts[2]) : 0
                    totalMinutes = Double(parts[0]) * 60 + Double(parts[1]) + seconds / 60
                }
            }
            if totalMinutes <= 0 { totalMinutes = Double(valid.count) / 60 }
            intervalMinutes = totalMinutes / Double(valid.count)
        }

        guard intervalMinutes > 0 else { return nil }

        var trimp = 0.0
        for point in valid {
            guard let value = point.value else { continue }
            let percent = value / Double(hrMax)
            let factor: Double
            switch percent {
            case 0.9...:      factor = 5
            case 0.8..<0.9:   factor = 4
            case 0.7..<0.8:   factor = 3
            case 0.6..<0.7:   factor = 2
            case 0.5..<0.6:   factor = 1
            default:          factor = 0
            }
            trimp += intervalMinutes * factor
        }
        return trimp > 0 ? trimp : nil
    }

    static func rating(_ trimp: Double) -> String {
        switch trimp {
        case ..<50:   return "Leicht"
        case ..<100:  return "Moderat"
        case ..<150:  return "Mittel"
        case ..<200:  return "Hart"
        case ..<300:  return "Sehr hart"
        default:      return "Extrem"
        }
    }

    static func color(_ trimp: Double) -> Color {
        switch trimp {
        case ..<50:   return AppColor.green
        case ..<100:  return AppColor.zoneModerate
        case ..<150:  return AppColor.orange
        case ..<200:  return AppColor.zoneIntense
        case ..<300:  return AppColor.cta
        default:      return AppColor.red
        }
    }

    /// Zonenfarbe eines einzelnen Messpunkts — dieselben Tokens wie in der
    /// Client-App.
    static func zoneColor(value: Double, hrMax: Int) -> Color {
        guard hrMax > 0 else { return AppColor.zoneVeryLight }
        switch value / Double(hrMax) {
        case 0.9...:     return AppColor.zoneMax
        case 0.8..<0.9:  return AppColor.zoneIntense
        case 0.7..<0.8:  return AppColor.zoneModerate
        case 0.6..<0.7:  return AppColor.zoneLight
        default:         return AppColor.zoneVeryLight
        }
    }
}
