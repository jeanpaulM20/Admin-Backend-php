import SwiftUI
import Charts

// MARK: - Nachrichtenblasen, Datumstrenner, Datenkarten

// MARK: - GroupedItem

struct GroupedItem: Identifiable {
    enum Content {
        case dateSeparator(String)
        case message(ChatMessage)
        case circleGroup([ChatMessage])
    }
    let content: Content

    /// Stabile Identität aus den zugrundeliegenden Nachrichten — mit UUID()
    /// würde die Liste bei jeder Body-Evaluation ihre Diffing-Identität verlieren.
    var id: String {
        switch content {
        case .dateSeparator(let label): return "sep-\(label)"
        case .message(let msg):         return "msg-\(msg.id)"
        case .circleGroup(let msgs):    return "circle-\(msgs.first?.id ?? "")"
        }
    }
}

// MARK: - DateSeparatorView

struct DateSeparatorView: View {
    let label: String
    var body: some View {
        HStack {
            line; Text(label).font(.caption2).foregroundStyle(AppColor.muted); line
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    private var line: some View {
        Rectangle().fill(AppColor.muted.opacity(0.3)).frame(height: 1)
    }
}

// MARK: - BubbleView

/// Pendant zu `_buildBubble` in `chat_screen.dart`.
/// Klient-Nachrichten: rechts, olive; Trainer-Nachrichten: links, surface mit Autor-Zeile.
struct BubbleView: View {
    let message:     ChatMessage
    let trainerName: String
    let onDataTap:   () -> Void

    private var isDataCard: Bool {
        let t = message.text
        return t.hasPrefix("[Aufzeichnung]") || t.hasPrefix("[Performance]")
            || t.hasPrefix("[Messwerte]")    || t.hasPrefix("[TRAINING_REPORT]")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isFromClient { Spacer(minLength: 60) }

            VStack(alignment: message.isFromClient ? .trailing : .leading, spacing: 4) {
                if isDataCard {
                    VStack(alignment: .leading, spacing: 3) {
                        authorRow
                        DataCardView(text: message.text, onTap: onDataTap)
                    }
                } else {
                    VStack(alignment: message.isFromClient ? .trailing : .leading, spacing: 3) {
                        authorRow
                        Text(message.text)
                            .font(.callout)
                            .foregroundStyle(message.isFromClient ? AppColor.white : AppColor.text)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromClient ? AppColor.primary : AppColor.surface,
                        in: RoundedRectangle(cornerRadius: AppRadius.hero)
                    )
                }

                if let date = message.createdAt {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(AppColor.muted)
                }
            }

            if message.isFromTrainer { Spacer(minLength: 60) }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.vertical, 2)
    }

    /// Autor-Zeile für Trainer-Nachrichten (Flutter: `msg.author ?? widget.trainerName`).
    @ViewBuilder
    private var authorRow: some View {
        if !message.isFromClient {
            Text(message.author ?? trainerName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColor.muted)
        }
    }
}

// MARK: - DataCardView

/// Pendant zu `_buildDataCard` in `chat_screen.dart`.
/// Erkennt Datennachrichten am Prefix und rendert eine Karte.
struct DataCardView: View {
    let text:  String
    let onTap: () -> Void

    private var info: (icon: String, tag: String) {
        if text.hasPrefix("[Aufzeichnung]")    { return ("figure.run", "Training") }
        if text.hasPrefix("[Performance]")     { return ("bolt.fill",   "Performance") }
        if text.hasPrefix("[Messwerte]")       { return ("scalemass",   "Messwerte") }
        if text.hasPrefix("[TRAINING_REPORT]") { return ("doc.text.fill","Report") }
        return ("doc", "Daten")
    }

    private var details: String {
        let raw = text
            .replacingOccurrences(of: "[Aufzeichnung]", with: "")
            .replacingOccurrences(of: "[Performance]",  with: "")
            .replacingOccurrences(of: "[Messwerte]",    with: "")
            .replacingOccurrences(of: "[TRAINING_REPORT]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Zeilenweise parsen, max 3 Zeilen zeigen
        return raw.components(separatedBy: "\n").prefix(3).joined(separator: "\n")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: info.icon)
                        .font(.callout)
                        .foregroundStyle(AppColor.primary)
                    Text(info.tag)
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.primary)
                }
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(3)
                }
                Text("Antippen für Details")
                    .font(.caption2)
                    .foregroundStyle(AppColor.primary.opacity(0.7))
            }
            .padding(12)
            .frame(maxWidth: 260, alignment: .leading)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColor.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
