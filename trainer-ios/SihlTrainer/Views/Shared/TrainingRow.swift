import SwiftUI

/// Termin-Zeile — geteilt von Übersicht, Trainings und (später) Kalender.
struct TrainingRow: View {
    let training: Training
    /// Im Kundendetail steht der Name schon im Kopf — dort wäre er in jeder
    /// Zeile nur Wiederholung.
    var showsClient = true
    /// Im Tagesdetail des Kalenders steht das Datum schon in der Überschrift.
    var showsDay = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                if showsDay {
                    Text(Self.dayFormatter.string(from: training.startTime ?? Date()))
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                }
                Text(Self.timeFormatter.string(from: training.startTime ?? Date()))
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
            }
            .frame(width: showsDay ? 56 : 44)

            Rectangle()
                .fill(training.isCancelled ? AppColor.red : AppColor.primary)
                .frame(width: 2)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                if let secondaryText {
                    Text(secondaryText)
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if training.isCancelled {
                Text(training.isLateCancellation ? "Spät abgesagt" : "Abgesagt")
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(AppColor.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.red.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    /// Mit Kundenname: Name oben, Art und Ort darunter. Ohne: die Art rückt
    /// nach oben, damit die Zeile nicht mit einer leeren Hierarchie beginnt.
    private var primaryText: String {
        if showsClient {
            return training.clientName ?? training.title ?? "Termin"
        }
        return training.trainingType ?? training.title ?? "Termin"
    }

    private var secondaryText: String? {
        var parts: [String] = []
        if showsClient, let type = training.trainingType { parts.append(type) }
        if let location = training.locationName { parts.append(location) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "EE dd.MM."
        return f
    }()

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "HH:mm"
        return f
    }()
}
