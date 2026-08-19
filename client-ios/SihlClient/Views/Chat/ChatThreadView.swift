import SwiftUI

// MARK: - ChatThreadView

/// Pendant zu `_ChatThread` in Flutter `chat_screen.dart`.
/// Zeigt Nachrichten mit Datum-Separatoren, Bubbles, Datenkarten und Kreis-Gruppen.
/// Realtime-Updates via SSE (`SSEClient`).
struct ChatThreadView: View {
    let trainerId:      String
    let trainerName:    String
    let trainerPicture: String?

    @Environment(AuthViewModel.self) private var auth
    @Environment(ChatViewModel.self) private var chat

    // Thread-lokaler State
    @State private var messages:     [ChatMessage] = []
    @State private var isLoading     = true
    @State private var messageText   = ""
    @State private var isSending     = false
    @State private var showAttach    = false
    @State private var dataDetail:   DataDetailItem? = nil
    @State private var sseTask:      Task<Void, Never>? = nil
    @State private var sse           = SSEClient()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(AppColor.primary)
                    Spacer()
                } else {
                    messageScrollView
                }
                inputBar
            }
        }
        .navigationTitle(trainerName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $dataDetail) { item in DataDetailSheet(item: item) }
        .sheet(isPresented: $showAttach) {
            AttachMenuSheet(clientId: auth.clientId, trainerId: trainerId, onShare: handleShare)
        }
        .task {
            await loadAndSubscribe()
        }
        .onDisappear {
            sseTask?.cancel()
            Task { await sse.disconnect() }
        }
    }

    // MARK: - Message scroll

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedItems, id: \.id) { item in
                        switch item.content {
                        case .dateSeparator(let label):
                            DateSeparatorView(label: label)
                        case .message(let msg):
                            if msg.isCircle {
                                CircleBadgeView(message: msg)
                            } else {
                                BubbleView(
                                    message: msg,
                                    onDataTap: { dataDetail = DataDetailItem(message: msg, clientId: auth.clientId) }
                                )
                            }
                        case .circleGroup(let msgs):
                            CircleGroupView(messages: msgs)
                        }
                    }
                }
                .padding(.vertical, 12)
                .id("bottom-anchor")
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
            }
            .onAppear {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { showAttach = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.primary)
            }
            TextField("Nachricht ...", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(AppColor.text)
            Button {
                Task { await sendMessage() }
            } label: {
                if isSending {
                    ProgressView().tint(AppColor.primary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? AppColor.muted : AppColor.primary)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColor.surface.opacity(0.95))
    }

    // MARK: - Load + SSE

    private func loadAndSubscribe() async {
        isLoading = true
        do {
            messages  = try await ChatService.shared.getMessages(clientId: auth.clientId, trainerId: trainerId)
        } catch {}
        isLoading = false

        // Als gelesen markieren
        await chat.markRead(clientId: auth.clientId, trainerId: trainerId)

        // SSE abonnieren (Kanal: client_{clientId})
        let clientId = auth.clientId
        let token    = auth.token ?? ""
        await sse.connect(channel: "client_\(clientId)", token: token) {
            [self] eventType in
            guard eventType == "chat" else { return }
            Task { @MainActor in
                // Nachrichten neu laden wenn neues Chat-Event
                if let fresh = try? await ChatService.shared.getMessages(
                    clientId: clientId, trainerId: self.trainerId) {
                    self.messages = fresh
                }
            }
        }
    }

    // MARK: - Send

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        messageText = ""
        if let msg = try? await ChatService.shared.sendMessage(
            clientId: auth.clientId, trainerId: trainerId, text: text) {
            messages.append(msg)
        }
        isSending = false
    }

    // MARK: - Attach share

    private func handleShare(text: String) {
        Task {
            if let msg = try? await ChatService.shared.sendMessage(
                clientId: auth.clientId, trainerId: trainerId, text: text) {
                messages.append(msg)
            }
        }
    }

    // MARK: - Grouped items (Datum-Separatoren + Kreis-Gruppen)

    private var groupedItems: [GroupedItem] {
        var result: [GroupedItem] = []
        var i = 0
        var lastDate: String? = nil
        let cal = Calendar.current

        while i < messages.count {
            let msg = messages[i]

            // Datum-Separator
            if let date = msg.createdAt {
                let label = dateLabel(date, cal: cal)
                if label != lastDate {
                    result.append(GroupedItem(content: .dateSeparator(label)))
                    lastDate = label
                }
            }

            // Kreis-Gruppe: aufeinanderfolgende isCircle-Nachrichten vom Trainer gruppieren
            if msg.isCircle && msg.isFromTrainer {
                var group: [ChatMessage] = [msg]
                i += 1
                while i < messages.count && messages[i].isCircle && messages[i].isFromTrainer {
                    group.append(messages[i])
                    i += 1
                }
                result.append(GroupedItem(content: .circleGroup(group)))
                continue
            }

            result.append(GroupedItem(content: .message(msg)))
            i += 1
        }
        return result
    }

    private func dateLabel(_ date: Date, cal: Calendar) -> String {
        if cal.isDateInToday(date)     { return "Heute" }
        if cal.isDateInYesterday(date) { return "Gestern" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd.MM.yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - GroupedItem

private struct GroupedItem: Identifiable {
    let id = UUID()
    enum Content {
        case dateSeparator(String)
        case message(ChatMessage)
        case circleGroup([ChatMessage])
    }
    let content: Content
}

// MARK: - DateSeparatorView

private struct DateSeparatorView: View {
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
/// Klient-Nachrichten: rechts, olive; Trainer-Nachrichten: links, surface.
private struct BubbleView: View {
    let message:   ChatMessage
    let onDataTap: () -> Void

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
                    DataCardView(text: message.text, onTap: onDataTap)
                } else {
                    Text(message.text)
                        .font(.callout)
                        .foregroundStyle(message.isFromClient ? AppColor.white : AppColor.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.isFromClient ? AppColor.primary : AppColor.surface,
                            in: RoundedRectangle(cornerRadius: 18)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - DataCardView

/// Pendant zu `_buildDataCard` in `chat_screen.dart`.
/// Erkennt Datennachrichten am Prefix und rendert eine Karte.
private struct DataCardView: View {
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
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColor.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - CircleGroupView

/// Pendant zu `_buildCircleGroup` in `chat_screen.dart`.
/// Aufeinanderfolgende Trainingskreis-Einträge werden als Summerkarte gezeigt.
private struct CircleGroupView: View {
    let messages: [ChatMessage]

    // Intensitätswerte aus dem Nachrichtentext extrahieren (z.B. "Intensität: 7/10")
    private var intensities: [Int] {
        messages.compactMap { msg -> Int? in
            let pattern = #"Intensität.*?(\d+)/10"#
            guard let range = msg.text.range(of: pattern, options: .regularExpression),
                  let numRange = msg.text[range].range(of: #"\d+"#, options: .regularExpression)
            else { return nil }
            return Int(msg.text[range][numRange])
        }
    }

    private var avgIntensity: Double? {
        guard !intensities.isEmpty else { return nil }
        return Double(intensities.reduce(0, +)) / Double(intensities.count)
    }
    private var maxIntensity: Int? { intensities.max() }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .foregroundStyle(AppColor.primary)
                    Text("\(messages.count) Trainingseinheit\(messages.count == 1 ? "" : "en")")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                }
                if let avg = avgIntensity, let max = maxIntensity {
                    Text("Intensität: Ø \(String(format: "%.1f", avg))/10 · Max \(max)/10")
                        .font(.caption)
                        .foregroundStyle(intensityColor(avg))
                }
            }
            .padding(12)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    /// Farbe analog zu Flutter `_intensityColor`: ≤3 grün, ≤6 orange, >6 rot.
    private func intensityColor(_ v: Double) -> Color {
        if v <= 3 { return .green }
        if v <= 6 { return .orange }
        return .red
    }
}

/// Einzel-Kreis-Badge (einzelne isCircle-Nachricht ohne Grouping).
private struct CircleBadgeView: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            Label(message.text.isEmpty ? "Trainingseinheit" : message.text,
                  systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(AppColor.primary)
                .padding(8)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 8))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - DataDetailItem + DataDetailSheet

/// Hilfsstruct für `.sheet(item:)` — übergibt Kontext an das Detail-Sheet.
struct DataDetailItem: Identifiable {
    let id      = UUID()
    let message: ChatMessage
    let clientId: String
}

/// Einfaches Detail-Sheet für Datenkarten.
/// Pendant zu `_ReviewDetailSheet`, `_PerformanceDetailSheet`, `_MetricDetailSheet`.
private struct DataDetailSheet: View {
    let item: DataDetailItem
    @State private var details: [[String: String]] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private var cardType: DataCardType {
        let t = item.message.text
        if t.hasPrefix("[Aufzeichnung]")    { return .review }
        if t.hasPrefix("[Performance]")     { return .performance }
        if t.hasPrefix("[Messwerte]")       { return .metrics }
        if t.hasPrefix("[TRAINING_REPORT]") { return .report }
        return .other
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(AppColor.primary)
                } else {
                    List {
                        ForEach(details, id: \.self) { row in
                            ForEach(row.sorted(by: { $0.key < $1.key }), id: \.key) { pair in
                                HStack {
                                    Text(pair.key)
                                        .font(.caption)
                                        .foregroundStyle(AppColor.muted)
                                    Spacer()
                                    Text(pair.value)
                                        .font(.caption.bold())
                                        .foregroundStyle(AppColor.text)
                                }
                                .listRowBackground(AppColor.surface)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(cardType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
        .task { await loadDetails() }
    }

    private func loadDetails() async {
        isLoading = true
        switch cardType {
        case .review:
            if let rows = try? await ChatService.shared.getReviews(clientId: item.clientId) {
                details = rows.prefix(5).map { dict in
                    var out: [String: String] = [:]
                    for (k, v) in dict { out[k] = "\(v)" }
                    return out
                }
            }
        case .performance:
            if let rows = try? await ChatService.shared.getPerformanceTests(clientId: item.clientId) {
                details = rows.prefix(5).map { dict in
                    var out: [String: String] = [:]
                    for (k, v) in dict { out[k] = "\(v)" }
                    return out
                }
            }
        default:
            // Nachrichtentext als Details anzeigen
            let lines = item.message.text
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .dropFirst() // Prefix entfernen
            details = [Dictionary(uniqueKeysWithValues: lines.enumerated().map {
                ("\($0.offset + 1).", $0.element)
            })]
        }
        isLoading = false
    }
}

private enum DataCardType {
    case review, performance, metrics, report, other
    var title: String {
        switch self {
        case .review:      return "Trainingsaufzeichnung"
        case .performance: return "Performance-Test"
        case .metrics:     return "Messwerte"
        case .report:      return "Trainings-Report"
        case .other:       return "Details"
        }
    }
}

// MARK: - AttachMenuSheet

/// Pendant zu Flutter's Attach-Menü (shareReviewData / sharePerformanceData).
private struct AttachMenuSheet: View {
    let clientId:  String
    let trainerId: String
    let onShare:   (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reviews:      [[String: Any]] = []
    @State private var tests:        [[String: Any]] = []
    @State private var isLoading     = true
    @State private var pickerType:   AttachPickerType? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                List {
                    Section("Teilen") {
                        Button {
                            pickerType = .review
                        } label: {
                            Label("Trainingsaufzeichnung", systemImage: "figure.run")
                                .foregroundStyle(AppColor.text)
                        }
                        .listRowBackground(AppColor.surface)

                        Button {
                            pickerType = .performance
                        } label: {
                            Label("Performance-Test", systemImage: "bolt.fill")
                                .foregroundStyle(AppColor.text)
                        }
                        .listRowBackground(AppColor.surface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Anhang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
            .sheet(item: $pickerType) { type in
                DataPickerSheet(
                    type:    type,
                    clientId: clientId,
                    onPick: { text in
                        onShare(text)
                        pickerType = nil
                        dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - DataPickerSheet

private enum AttachPickerType: String, Identifiable {
    case review, performance
    var id: String { rawValue }
    var title: String { self == .review ? "Trainingsaufzeichnung" : "Performance-Test" }
    var prefix: String { self == .review ? "[Aufzeichnung]" : "[Performance]" }
}

private struct DataPickerSheet: View {
    let type:     AttachPickerType
    let clientId: String
    let onPick:   (String) -> Void
    @State private var items:     [[String: Any]] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(AppColor.primary)
                } else if items.isEmpty {
                    Text("Keine Daten vorhanden")
                        .foregroundStyle(AppColor.muted)
                } else {
                    List {
                        ForEach(items.indices, id: \.self) { idx in
                            let item = items[idx]
                            Button {
                                let lines = item.sorted(by: { $0.key < $1.key })
                                    .map { "\($0.key): \($0.value)" }
                                    .joined(separator: "\n")
                                onPick("\(type.prefix)\n\(lines)")
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Eintrag \(idx + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppColor.text)
                                    if let date = item["date"] as? String ?? item["created_at"] as? String {
                                        Text(date)
                                            .font(.caption)
                                            .foregroundStyle(AppColor.muted)
                                    }
                                }
                            }
                            .listRowBackground(AppColor.surface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .task { await load() }
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
        } catch {}
        isLoading = false
    }
}
