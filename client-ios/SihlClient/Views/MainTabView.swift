import SwiftUI

/// Pendant zu Flutter `main_screen.dart` — Tab-Shell mit 5 Tabs + Profil-Avatar.
///
/// Struktur: TabView an der Wurzel, EIN NavigationStack PRO Tab (kanonisches
/// SwiftUI-Muster). Ein NavigationStack UM den TabView bricht auf neueren
/// iOS-Versionen das Hit-Testing von Buttons/NavigationLinks im Tab-Inhalt.
/// Maximal 5 Tabs! Ein 6. Tab landet in iOS' automatischem "More"-Tab, in dem
/// wertbasierte Navigation nicht funktioniert — Blutzucker lebt deshalb unter
/// Profil → Blutzucker.
struct MainTabView: View {
    @Environment(AuthViewModel.self)  private var auth
    @Environment(ChatViewModel.self)  private var chat
    @State private var selection = 0

    private enum TabIndex: Int { case start, touren, kalender, chat, analytics }

    @Environment(StartViewModel.self) private var start

    var body: some View {
        TabView(selection: $selection) {

            // ── Tab 0: Start — Training aufzeichnen ──────────────────────
            TabRoot(title: "Training aufzeichnen") { RecordWorkoutView() }
                .tabItem { Label("Start", systemImage: "record.circle") }
                .tag(TabIndex.start.rawValue)

            // ── Tab 1: Touren — direkt die Karte (Pläne liegen im Profil)
            TabRoot(title: "") { TourDiscoveryView() }
                .tabItem { Label("Touren", systemImage: "map.fill") }
                .tag(TabIndex.touren.rawValue)

            // ── Tab 2: Kalender ──────────────────────────────────────────
            TabRoot(title: "Kalender") { CalendarView() }
                .tabItem { Label("Kalender", systemImage: "calendar") }
                .tag(TabIndex.kalender.rawValue)

            // ── Tab 3: Chat (mit Unread-Badge wie Flutter `_buildNavIcon`) ─
            TabRoot(title: "Chat") { ChatView() }
                .tabItem { Label("Chat", systemImage: "bubble.left") }
                .badge(chat.totalUnreadCount)
                .tag(TabIndex.chat.rawValue)

            // ── Tab 4: Analytics ─────────────────────────────────────────
            TabRoot(title: "Auswertung") { AnalyticsView() }
                .tabItem { Label("Auswertung", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(TabIndex.analytics.rawValue)
        }
        .task {
            // Conversations schon beim App-Start laden, damit der Unread-Badge
            // sichtbar ist, bevor der Chat-Tab je geöffnet wurde (Flutter lädt
            // alle Screens eager im IndexedStack).
            if chat.conversations.isEmpty, let id = auth.clientId {
                await chat.fetchConversations(clientId: id)
            }
            // Offline aufgezeichnete Trainings nachreichen
            await WorkoutUploadService.shared.retryPending()
            // Stammdaten für die Avatar-Initialen (kam bisher aus der Startseite)
            if start.startData == nil, let id = auth.clientId {
                await start.load(clientId: id)
            }
        }
    }
}

// MARK: - TabRoot

/// Gemeinsames Gerüst pro Tab: eigener NavigationStack, Titel,
/// Profil-Avatar in der Toolbar.
private struct TabRoot<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(StartViewModel.self) private var start

    var body: some View {
        NavigationStack {
            content()
                .toolbarBackground(AppColor.surface, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            ProfileView()
                        } label: {
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
                                            .font(.app(13, weight: .bold))
                                            .foregroundStyle(AppColor.white)
                                    }
                                }
                        }
                    }
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
}
