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
    @State private var toast:        String? = nil
    @State private var toastNonce    = 0
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Titel + Untertitel "N Nachrichten · M Workouts" (Flutter `_getStatusText`)
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(trainerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(AppColor.muted)
                }
            }
            // Refresh-Button (Flutter: Icons.refresh, Tooltip "Aktualisieren")
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                }
                .accessibilityLabel("Aktualisieren")
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                ToastView(message: t)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toastNonce) {
                        // Pro Toast ein eigener, automatisch gecancelter Timer —
                        // ein alter Timer kann so keinen neueren Toast abräumen.
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { toast = nil }
                    }
            }
        }
        .sheet(item: $dataDetail) { item in
            DataDetailRouterView(item: item)
        }
        .sheet(isPresented: $showAttach) {
            AttachMenuSheet(clientId: auth.clientId ?? "") { text in
                // Wie Flutter: Auswahl landet im Eingabefeld (editierbar), wird NICHT sofort gesendet
                messageText = text
                showAttach  = false
            }
        }
        .task {
            await loadAndSubscribe()
        }
        .onDisappear {
            Task { await sse.disconnect() }
        }
    }

    /// Pendant zu Flutter `_getStatusText`: "N Nachrichten · M Workouts".
    private var statusText: String {
        var msgCount = 0, circleCount = 0
        for m in messages { if m.isCircle { circleCount += 1 } else { msgCount += 1 } }
        var parts: [String] = []
        if msgCount    > 0 { parts.append("\(msgCount) Nachrichten") }
        if circleCount > 0 { parts.append("\(circleCount) Workouts") }
        return parts.isEmpty ? "Chat" : parts.joined(separator: " · ")
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
                            BubbleView(
                                message:     msg,
                                trainerName: trainerName,
                                onDataTap: { dataDetail = DataDetailItem(message: msg, clientId: auth.clientId ?? "") }
                            )
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
            messages  = try await ChatService.shared.getMessages(clientId: auth.clientId ?? "", trainerId: trainerId)
        } catch {}
        isLoading = false

        // Als gelesen markieren
        await chat.markRead(clientId: auth.clientId ?? "", trainerId: trainerId)

        // SSE abonnieren (Kanal: client_{clientId}) — nur mit gültiger Session,
        // sonst würde der Reconnect-Loop endlos einen leeren Kanal abonnieren.
        guard let clientId = auth.clientId, !clientId.isEmpty,
              let token = auth.token, !token.isEmpty else { return }
        await sse.connect(channel: "client_\(clientId)", token: token) {
            [self] eventType in
            guard eventType == "chat" else { return }
            Task { @MainActor in
                // Wie Flutter `_refresh`: neu laden UND als gelesen markieren,
                // sonst bleibt die Nachricht serverseitig ungelesen.
                if let fresh = try? await ChatService.shared.getMessages(
                    clientId: clientId, trainerId: self.trainerId) {
                    self.messages = fresh
                }
                await self.chat.markRead(clientId: clientId, trainerId: self.trainerId)
            }
        }
    }

    /// Pendant zu Flutter `_refresh`: Nachrichten neu laden + als gelesen markieren.
    private func refresh() async {
        if let fresh = try? await ChatService.shared.getMessages(
            clientId: auth.clientId ?? "", trainerId: trainerId) {
            messages = fresh
        }
        await chat.markRead(clientId: auth.clientId ?? "", trainerId: trainerId)
    }

    // MARK: - Send

    /// Pendant zu Flutter `_send`: bei Fehlschlag Text zurücklegen + Fehlermeldung.
    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        let savedText = messageText
        messageText = ""
        do {
            if let msg = try await ChatService.shared.sendMessage(
                clientId: auth.clientId ?? "", trainerId: trainerId, text: text) {
                messages.append(msg)
            }
        } catch {
            // Text wiederherstellen, damit erneut gesendet werden kann
            messageText = savedText
            toastNonce += 1
            withAnimation { toast = "Nachricht konnte nicht gesendet werden" }
        }
        isSending = false
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

            // Kreis-Gruppe: ALLE aufeinanderfolgenden isCircle-Nachrichten gruppieren
            // (wie Flutter `_buildGroupedWidgets`, ohne Sender-Einschränkung)
            if msg.isCircle {
                var group: [ChatMessage] = [msg]
                i += 1
                while i < messages.count && messages[i].isCircle {
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
        return DateFormatter.chatDDMMYYYY.string(from: date)
    }
}

// MARK: - GroupedItem

private struct GroupedItem: Identifiable {
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
/// Klient-Nachrichten: rechts, olive; Trainer-Nachrichten: links, surface mit Autor-Zeile.
private struct BubbleView: View {
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

// MARK: - Intensität (gemeinsame Helfer)

/// Farbe analog zu Flutter `_intensityColor`: ≤3 grün, ≤6 orange, >6 rot.
private func intensityColor(_ v: Int) -> Color {
    if v <= 3 { return AppColor.green }
    if v <= 6 { return AppColor.orange }
    return AppColor.red
}

// MARK: - CircleGroupView

/// Pendant zu `_buildCircleGroup` in `chat_screen.dart`.
/// Aufeinanderfolgende Trainingskreis-Einträge werden als Summenkarte gezeigt;
/// Tap öffnet das Kachel-Grid (`_showCirclesExpanded`), Kachel-Tap das
/// Intensitätsrad (`_showCircleDetail`).
private struct CircleGroupView: View {
    let messages: [ChatMessage]

    @State private var showExpanded  = false
    @State private var pendingDetail: Int? = nil
    @State private var detailValue:   CircleDetailValue? = nil

    /// Intensitätswerte: Zahl direkt aus dem Nachrichtentext (Flutter: `int.tryParse(c.text) ?? 0`).
    private var values: [Int] {
        messages.map { Int($0.text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
    }

    private var avg: Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }
    private var maxVal: Int { values.max() ?? 0 }

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button { showExpanded = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(intensityColor(Int(avg.rounded())).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "dumbbell.fill")
                            .font(.footnote)
                            .foregroundStyle(intensityColor(Int(avg.rounded())))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(messages.count) Trainingseinheiten")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppColor.text)
                        Text("Intensitaet: Ø \(String(format: "%.1f", avg))/10 · Max \(maxVal)/10")
                            .font(.caption2)
                            .foregroundStyle(AppColor.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColor.primary.opacity(0.24), lineWidth: 0.5)
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sheet(isPresented: $showExpanded, onDismiss: {
            if let v = pendingDetail {
                pendingDetail = nil
                detailValue   = CircleDetailValue(value: v)
            }
        }) {
            CirclesExpandedSheet(values: values) { v in
                pendingDetail = v
                showExpanded  = false
            }
        }
        .sheet(item: $detailValue) { d in
            CircleDetailSheet(value: d.value)
        }
    }
}

private struct CircleDetailValue: Identifiable {
    let id = UUID()
    let value: Int
}

// MARK: - CirclesExpandedSheet

/// Pendant zu Flutter `_showCirclesExpanded`: Kachel-Grid aller Circles.
private struct CirclesExpandedSheet: View {
    let values:   [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.callout)
                        .foregroundStyle(AppColor.primary)
                    Text("Trainingsintensitaeten (\(values.count))")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 60), spacing: 8)],
                              alignment: .leading, spacing: 8) {
                        ForEach(values.indices, id: \.self) { i in
                            let val = values[i]
                            Button { onSelect(val) } label: {
                                VStack(spacing: 0) {
                                    Text("\(val)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(intensityColor(val))
                                    Text("/10")
                                        .font(.system(size: 10))
                                        .foregroundStyle(intensityColor(val).opacity(0.6))
                                }
                                .frame(width: 60, height: 60)
                                .background(intensityColor(val).opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(intensityColor(val).opacity(0.31), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - CircleDetailSheet (Intensitätsrad)

/// Pendant zu Flutter `_showCircleDetail` + `_WheelSectorPainter`:
/// 10-Sektoren-Rad, gefüllt bis Intensitätswert, Rest gedimmt.
private struct CircleDetailSheet: View {
    let value: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColor.surface.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Trainingsintensitaet")
                    .font(.callout)
                    .foregroundStyle(AppColor.text)

                ZStack {
                    ForEach(0..<10, id: \.self) { i in
                        WheelSectorShape(sectorCount: 10, sectorIndex: i)
                            .fill(sectorColor(index: i, isActive: (i + 1) <= value))
                    }
                    Circle()
                        .fill(AppColor.background)
                        .frame(width: 72, height: 72)
                    Text("\(value)/10")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColor.text)
                }
                .frame(width: 240, height: 240)

                Button("Schließen") { dismiss() }
                    .font(.callout)
                    .foregroundStyle(AppColor.primary)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Aktiv: Verlauf Grün → Dunkelrot je Sektor-Index (wie Flutter `Color.lerp`);
    /// inaktiv: Border-Farbe (gedimmt).
    private func sectorColor(index: Int, isActive: Bool) -> Color {
        guard isActive else { return AppColor.border }
        let t = Double(index) / 9.0
        return lerpColor(AppColor.green, AppColor.red, t)
    }

    private func lerpColor(_ a: Color, _ b: Color, _ t: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(min(max(t, 0), 1))
        return Color(.sRGB,
                     red:     Double(r1 + (r2 - r1) * f),
                     green:   Double(g1 + (g2 - g1) * f),
                     blue:    Double(b1 + (b2 - b1) * f),
                     opacity: Double(a1 + (a2 - a1) * f))
    }
}

/// SwiftUI-Port von Flutter `_WheelSectorPainter`: ein ringförmiger Sektor.
private struct WheelSectorShape: Shape {
    let sectorCount: Int
    let sectorIndex: Int

    func path(in rect: CGRect) -> Path {
        let center      = CGPoint(x: rect.midX, y: rect.midY)
        let radius      = min(rect.width, rect.height) / 2 - 4
        let innerRadius = radius * 0.35
        let gapAngle    = 0.04
        let sweepAngle  = (2 * Double.pi / Double(sectorCount)) - gapAngle
        let startAngle  = -Double.pi / 2
                        + Double(sectorIndex) * (2 * Double.pi / Double(sectorCount))
                        + gapAngle / 2

        var p = Path()
        p.move(to: point(center, innerRadius, startAngle))
        p.addLine(to: point(center, radius, startAngle))
        p.addArc(center: center, radius: radius,
                 startAngle: .radians(startAngle),
                 endAngle:   .radians(startAngle + sweepAngle),
                 clockwise:  false)
        p.addLine(to: point(center, innerRadius, startAngle + sweepAngle))
        p.addArc(center: center, radius: innerRadius,
                 startAngle: .radians(startAngle + sweepAngle),
                 endAngle:   .radians(startAngle),
                 clockwise:  true)
        p.closeSubpath()
        return p
    }

    private func point(_ c: CGPoint, _ r: Double, _ angle: Double) -> CGPoint {
        CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
    }
}

// MARK: - DataDetailItem + Router

/// Hilfsstruct für `.sheet(item:)` — übergibt Kontext an das Detail-Sheet.
struct DataDetailItem: Identifiable {
    let id      = UUID()
    let message: ChatMessage
    let clientId: String
}

/// Pendant zu Flutter `_showDataPopup`: routet je Prefix auf das passende Detail-Sheet.
private struct DataDetailRouterView: View {
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
private func extractChatDate(_ text: String) -> String? {
    guard let r = text.range(of: #"\d{2}\.\d{2}\.\d{4}"#, options: .regularExpression) else { return nil }
    return String(text[r])
}

/// Vergleicht ein rohes DB-Datum (ISO/`yyyy-MM-dd`) mit "dd.MM.yyyy".
private func chatDateMatches(_ rawDbDate: String?, _ ddMMyyyy: String?) -> Bool {
    guard let raw = rawDbDate, let target = ddMMyyyy else { return false }
    if let d = parseChatAPIDate(raw) {
        return DateFormatter.chatDDMMYYYY.string(from: d) == target
    }
    return raw.contains(target)
}

private func parseChatAPIDate(_ raw: String) -> Date? {
    DateFormatter.chatISO8601.date(from: raw)
        ?? DateFormatter.chatYYYYMMDDHHMMSS.date(from: raw)
        ?? DateFormatter.chatYYYYMMDD.date(from: raw)
}

/// Formatiert ein rohes API-Datum als "dd.MM.yyyy" (Flutter `_fmtDate`).
private func fmtChatDate(_ raw: String?) -> String {
    guard let raw, !raw.isEmpty else { return "--" }
    guard let d = parseChatAPIDate(raw) else { return raw }
    return DateFormatter.chatDDMMYYYY.string(from: d)
}

/// Trainingstyp-Labels (Flutter `_trainingTypeLabel`).
private func trainingTypeLabel(_ type: String?) -> String {
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
private func jsonString(_ v: Any?, fallback: String = "--") -> String {
    guard let v, !(v is NSNull) else { return fallback }
    return "\(v)"
}

/// Wert nur zurückgeben, wenn vorhanden und != 0 (Flutter: `value != null && value != 0`).
private func nonZeroValue(_ v: Any?) -> String? {
    guard let v, !(v is NSNull) else { return nil }
    if let n = v as? NSNumber { return n.doubleValue == 0 ? nil : "\(n)" }
    let s = "\(v)"
    if s.isEmpty || s == "0" || s == "0.0" { return nil }
    return s
}

// MARK: - ReviewDetailSheet

/// Pendant zu Flutter `_ReviewDetailSheet`: HR-Chart, Edwards-TRIMP, HF-Zonen-Legende, Stat-Cards.
private struct ReviewDetailSheet: View {
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColor.red.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundStyle(AppColor.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trainingTypeLabel(r.trainingType.isEmpty ? nil : r.trainingType))
                            .font(.system(size: 18, weight: .semibold))
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
        .background(AppColor.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ReviewHrChartSection

/// HR-Verlaufschart mit Max-Linie + HF-Zonen-Legende
/// (Pendant zu Flutter `_buildHrChart` / `_buildZoneLegend`).
/// Das Chart selbst kommt aus dem geteilten `HrLineChart` (Analytics).
private struct ReviewHrChartSection: View {
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
                        .font(.system(size: 10))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
    }
}

// MARK: - PerformanceDetailSheet

/// Pendant zu Flutter `_PerformanceDetailSheet`.
private struct PerformanceDetailSheet: View {
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColor.green.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundStyle(AppColor.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Performance Test")
                            .font(.system(size: 18, weight: .semibold))
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppColor.text)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
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
private struct MetricDetailSheet: View {
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
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private func load() async {
        if let json = try? await APIClient.shared.getJSONObject("api/client/profile/\(clientId)") {
            metric = json
        }
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColor.blue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "scalemass")
                            .font(.title3)
                            .foregroundStyle(AppColor.blue)
                    }
                    Text("Koerperwerte")
                        .font(.system(size: 18, weight: .semibold))
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
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColor.text)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColor.background, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - AttachMenuSheet

/// Pendant zu Flutter `_showAttachMenu`: "Daten teilen" mit zwei Optionen.
/// Auswahl im Picker füllt das Eingabefeld (kein direktes Senden).
private struct AttachMenuSheet: View {
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
                    RoundedRectangle(cornerRadius: 10)
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

private enum AttachPickerType: String, Identifiable {
    case review, performance
    var id: String { rawValue }
    /// Flutter: "Aufzeichnung wählen" / "Performance Test wählen".
    var title: String { self == .review ? "Aufzeichnung wählen" : "Performance Test wählen" }
}

/// Pendant zu Flutter `_showPickerSheet` + `_shareReviewData` / `_sharePerformanceData`:
/// Zeilen zeigen Typ + Datum + HR bzw. Testdatum + Punkte; Auswahl formatiert den
/// Text für das Eingabefeld.
private struct DataPickerSheet: View {
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
                            RoundedRectangle(cornerRadius: 10)
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

private extension DateFormatter {
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
