import SwiftUI

/// Pendant zu Flutter `main_screen.dart` — Tab-Shell mit 5 Tabs + Profil-Avatar.
/// Übersetzte Screens ersetzen schrittweise die PlaceholderScreen-Einträge.
struct MainTabView: View {
    @Environment(AuthViewModel.self)  private var auth
    @Environment(ChatViewModel.self)  private var chat
    @Environment(StartViewModel.self) private var start
    @State private var selection = 0
    @State private var showProfile = false

    // Tab-Metadaten für Titel und Icons
    private enum TabIndex: Int { case start, training, kalender, chat, analytics, blutzucker }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {

                // ── Tab 0: Start ─────────────────────────────────────────────
                StartView(onGoToCalendar: { selection = TabIndex.kalender.rawValue })
                    .tabItem { Label("Start", systemImage: "house.fill") }
                    .tag(TabIndex.start.rawValue)

                // ── Tab 1: Training ──────────────────────────────────────────
                TrainingView()
                    .tabItem { Label("Training", systemImage: "dumbbell.fill") }
                    .tag(TabIndex.training.rawValue)

                // ── Tab 2: Kalender ──────────────────────────────────────────
                CalendarView()
                    .tabItem { Label("Kalender", systemImage: "calendar") }
                    .tag(TabIndex.kalender.rawValue)

                // ── Tab 3: Chat (mit Unread-Badge wie Flutter `_buildNavIcon`) ─
                ChatView()
                    .tabItem { Label("Chat", systemImage: "bubble.left") }
                    .badge(chat.totalUnreadCount)
                    .tag(TabIndex.chat.rawValue)

                // ── Tab 4: Analytics ─────────────────────────────────────────
                AnalyticsView()
                    .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(TabIndex.analytics.rawValue)

                // ── Tab 5: Blutzucker (CGM) ──────────────────────────────────
                GlucoseView()
                    .tabItem { Label("Blutzucker", systemImage: "waveform.path.ecg") }
                    .tag(TabIndex.blutzucker.rawValue)
            }
            .toolbarBackground(AppColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle(tabTitle(for: selection))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Circle()
                            .fill(AppColor.primary)
                            .frame(width: 36, height: 36)
                            .overlay {
                                // Initialen aus Vor-/Nachname (Flutter `_buildInitials`),
                                // Fallback: person-Icon solange keine Start-Daten geladen sind
                                if avatarInitials.isEmpty {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(AppColor.white)
                                } else {
                                    Text(avatarInitials)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColor.white)
                                }
                            }
                    }
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
        }
        .task {
            // Conversations schon beim App-Start laden, damit der Unread-Badge
            // sichtbar ist, bevor der Chat-Tab je geöffnet wurde (Flutter lädt
            // alle Screens eager im IndexedStack).
            if chat.conversations.isEmpty, let id = auth.clientId {
                await chat.fetchConversations(clientId: id)
            }
        }
    }

    /// Pendant zu Flutter `_buildInitials`: erste Buchstaben von Vor- und Nachname.
    private var avatarInitials: String {
        let f = start.startData?.firstName.trimmingCharacters(in: .whitespaces) ?? ""
        let l = start.startData?.lastName.trimmingCharacters(in: .whitespaces) ?? ""
        let fi = f.first.map(String.init) ?? ""
        let li = l.first.map(String.init) ?? ""
        return (fi + li).uppercased()
    }

    private func tabTitle(for index: Int) -> String {
        switch TabIndex(rawValue: index) {
        case .start:       return "Start"
        case .training:    return "Training"
        case .kalender:    return "Kalender"
        case .chat:        return "Chat"
        case .analytics:   return "Analytics"
        case .blutzucker:  return "Blutzucker"
        case .none:        return ""
        }
    }
}

/// Temporärer Platzhalter, bis der jeweilige Screen übersetzt ist.
struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(title).font(.title2.bold()).foregroundStyle(AppColor.text)
                Text("Noch zu übersetzen").font(.footnote).foregroundStyle(AppColor.muted)
            }
        }
    }
}
