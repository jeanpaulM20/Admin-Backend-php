import SwiftUI
import Charts

// MARK: - Anhang-Menü und Datenauswahl

// MARK: - AttachMenuSheet

/// Pendant zu Flutter `_showAttachMenu`: "Daten teilen" mit zwei Optionen.
/// Auswahl im Picker füllt das Eingabefeld (kein direktes Senden).
struct AttachMenuSheet: View {
    let clientId: String
    let onPick:   (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerType: AttachPickerType? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                List {
                    Section {
                        attachOption(
                            icon:     "waveform.path.ecg",
                            label:    "Trainings-Aufzeichnung",
                            subtitle: "Letzte Trainingsaufzeichnung teilen",
                            color:    AppColor.red
                        ) { pickerType = .review }

                        attachOption(
                            icon:     "chart.line.uptrend.xyaxis",
                            label:    "Performance Daten",
                            subtitle: "Leistungstest-Ergebnisse teilen",
                            color:    AppColor.green
                        ) { pickerType = .performance }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Daten teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
            .sheet(item: $pickerType) { type in
                DataPickerSheet(type: type, clientId: clientId) { text in
                    pickerType = nil
                    onPick(text)
                }
            }
        }
    }

    private func attachOption(icon: String, label: String, subtitle: String,
                              color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .listRowBackground(AppColor.surface)
    }
}

// MARK: - DataPickerSheet

enum AttachPickerType: String, Identifiable {
    case review, performance
    var id: String { rawValue }
    /// Flutter: "Aufzeichnung wählen" / "Performance Test wählen".
    var title: String { self == .review ? "Aufzeichnung wählen" : "Performance Test wählen" }
}

/// Pendant zu Flutter `_showPickerSheet` + `_shareReviewData` / `_sharePerformanceData`:
/// Zeilen zeigen Typ + Datum + HR bzw. Testdatum + Punkte; Auswahl formatiert den
/// Text für das Eingabefeld.
struct DataPickerSheet: View {
    let type:     AttachPickerType
    let clientId: String
    let onPick:   (String) -> Void
    @State private var items:     [[String: Any]] = []
    @State private var isLoading  = true
    @State private var loadError  = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(AppColor.primary)
                } else if loadError {
                    Text("Daten konnten nicht geladen werden")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                } else if items.isEmpty {
                    Text(type == .review
                         ? "Keine Aufzeichnungen vorhanden"
                         : "Keine Performance-Daten vorhanden")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                } else {
                    itemList
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(items.count) Einträge")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .task { await load() }
    }

    private var itemList: some View {
        List {
            // Wie Flutter: Liste in umgekehrter Reihenfolge (neueste zuerst)
            ForEach(Array(items.enumerated().reversed()), id: \.offset) { _, item in
                Button {
                    onPick(shareText(for: item))
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.control)
                                .fill(accentColor.opacity(0.1))
                                .frame(width: 38, height: 38)
                            Image(systemName: iconName)
                                .font(.footnote)
                                .foregroundStyle(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rowTitle(for: item))
                                .font(.callout)
                                .foregroundStyle(AppColor.text)
                            Text(rowSubtitle(for: item))
                                .font(.caption)
                                .foregroundStyle(AppColor.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .listRowBackground(AppColor.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var iconName:    String { type == .review ? "waveform.path.ecg" : "chart.line.uptrend.xyaxis" }
    private var accentColor: Color  { type == .review ? AppColor.red : AppColor.green }

    // MARK: Zeilen-Texte (Flutter titleBuilder / subtitleBuilder)

    private func rowTitle(for item: [String: Any]) -> String {
        switch type {
        case .review:
            let typeLabel = trainingTypeLabel(item["trainingType"] as? String)
            return "\(typeLabel) -- \(fmtChatDate(item["date"] as? String))"
        case .performance:
            return "Test vom \(fmtChatDate(item["date"] as? String))"
        }
    }

    private func rowSubtitle(for item: [String: Any]) -> String {
        switch type {
        case .review:
            let duration = jsonString(item["duration"])
            let hr       = jsonString(item["hrAvg"])
            return "Dauer: \(duration) | HR: \(hr) bpm"
        case .performance:
            var parts = ["Punkte: \(jsonString(item["points"], fallback: "0"))"]
            if let pushups = nonZeroValue(item["pushups"]) { parts.append("Liegestuetz: \(pushups)") }
            if let pullups = nonZeroValue(item["pullups"]) { parts.append("Klimmzuege: \(pullups)") }
            return parts.joined(separator: " | ")
        }
    }

    // MARK: Auswahl-Text fürs Eingabefeld (Flutter onSelect)

    private func shareText(for item: [String: Any]) -> String {
        switch type {
        case .review:
            let typeLabel = trainingTypeLabel(item["trainingType"] as? String)
            let duration  = jsonString(item["duration"])
            let hr        = jsonString(item["hrAvg"])
            let date      = fmtChatDate(item["date"] as? String)
            return "[Aufzeichnung] \(typeLabel) (\(date))\nDauer: \(duration) | HR: \(hr) bpm"
        case .performance:
            let date = fmtChatDate(item["date"] as? String)
            var parts = ["Punkte: \(jsonString(item["points"], fallback: "0"))"]
            if let pushups = nonZeroValue(item["pushups"]) { parts.append("Liegestuetz: \(pushups)") }
            if let pullups = nonZeroValue(item["pullups"]) { parts.append("Klimmzuege: \(pullups)") }
            if let forearm = nonZeroValue(item["forearm_support"]) { parts.append("Unterarmstuetz: \(forearm)") }
            return "[Performance] Test (\(date))\n\(parts.joined(separator: " | "))"
        }
    }

    private func load() async {
        isLoading = true
        do {
            switch type {
            case .review:
                items = try await ChatService.shared.getReviews(clientId: clientId)
            case .performance:
                items = try await ChatService.shared.getPerformanceTests(clientId: clientId)
            }
        } catch {
            loadError = true
        }
        isLoading = false
    }
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    /// API-Datumsformate: fixe POSIX-Locale + gregorianischer Kalender, damit
    /// Parsen/Formatieren unabhängig vom Gerätekalender funktioniert
    /// (z.B. buddhistischer Kalender würde sonst Jahr 2569 liefern).
    private static func apiFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }
    static let chatDDMMYYYY      = apiFormatter("dd.MM.yyyy")
    static let chatYYYYMMDD      = apiFormatter("yyyy-MM-dd")
    static let chatYYYYMMDDHHMMSS = apiFormatter("yyyy-MM-dd HH:mm:ss")
    static let chatISO8601 = ISO8601DateFormatter()
}
