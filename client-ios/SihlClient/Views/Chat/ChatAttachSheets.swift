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
                            label:    "Performance-Daten",
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
    var title: String { self == .review ? "Aufzeichnung wählen" : "Performance-Test wählen" }
}

/// Pendant zu Flutter `_showPickerSheet` + `_shareReviewData` / `_sharePerformanceData`:
/// Zeilen zeigen Typ + Datum + HF bzw. Testdatum + Punkte; Auswahl formatiert den
/// Text für das Eingabefeld.
struct DataPickerSheet: View {
    let type:     AttachPickerType
    let clientId: String
    let onPick:   (String) -> Void
    @State private var rows:      [PickerRow] = []
    @State private var isLoading  = true
    @State private var loadError  = false
    @Environment(\.dismiss) private var dismiss

    /// Eine auswählbare Zeile (Titel, Untertitel, Text fürs Eingabefeld).
    struct PickerRow: Identifiable {
        let id:       String
        let title:    String
        let subtitle: String
        let share:    String
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(AppColor.primary)
                } else if loadError {
                    ErrorStateView(message: "Daten konnten nicht geladen werden") {
                        Task { await load() }
                    }
                } else if rows.isEmpty {
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
                    Text("\(rows.count) Einträge")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .task { await load() }
    }

    private var itemList: some View {
        List {
            ForEach(rows) { row in
                Button {
                    onPick(row.share)
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
                            Text(row.title)
                                .font(.callout)
                                .foregroundStyle(AppColor.text)
                            Text(row.subtitle)
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

    // MARK: Zeilen (Flutter titleBuilder / subtitleBuilder / onSelect)

    private static func reviewRow(_ item: [String: Any], index: Int) -> PickerRow {
        let typeLabel = trainingTypeLabel(item["trainingType"] as? String)
        let date      = fmtChatDate(item["date"] as? String)
        let duration  = jsonString(item["duration"])
        let hr        = jsonString(item["hrAvg"])
        let stats     = "Dauer: \(duration) | HF: \(hr) bpm"
        return PickerRow(
            id:       jsonID(item["id"]) ?? "idx-\(index)",
            title:    "\(typeLabel) – \(date)",
            subtitle: stats,
            share:    "[Aufzeichnung] \(typeLabel) (\(date))\n\(stats)"
        )
    }

    private static func performanceRow(_ test: PerformanceTestEntry) -> PickerRow {
        let date = fmtChatDate(test.date)
        var parts = ["Punkte: \(nonZeroValue(test.value("Gesamtpunkte")) ?? "0")"]
        if let v = nonZeroValue(test.value("Liegestütze")) { parts.append("Liegestütze: \(v)") }
        if let v = nonZeroValue(test.value("Klimmzüge"))   { parts.append("Klimmzüge: \(v)") }
        let subtitle = parts.joined(separator: " | ")
        if let v = nonZeroValue(test.value("Unterarmstütz")) { parts.append("Unterarmstütz: \(v)") }
        return PickerRow(
            id:       test.id,
            title:    "Test vom \(date)",
            subtitle: subtitle,
            share:    "[Performance] Test (\(date))\n\(parts.joined(separator: " | "))"
        )
    }

    private func load() async {
        isLoading = true
        loadError = false
        do {
            switch type {
            case .review:
                let items = try await ChatService.shared.getReviews(clientId: clientId)
                // Wie Flutter: neueste zuerst
                rows = items.enumerated().reversed().map { Self.reviewRow($0.element, index: $0.offset) }
            case .performance:
                // Bereits neueste zuerst
                rows = try await ChatService.shared.getPerformanceTests(clientId: clientId)
                    .map(Self.performanceRow)
            }
        } catch {
            loadError = true
        }
        isLoading = false
    }
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    /// "dd.MM.yyyy" — POSIX, gregorianisch, Zürcher Zeit (unabhängig vom
    /// Gerätekalender; buddhistischer Kalender würde sonst Jahr 2569 liefern).
    static let chatDDMMYYYY = ZurichTime.apiFormatter("dd.MM.yyyy")
}
