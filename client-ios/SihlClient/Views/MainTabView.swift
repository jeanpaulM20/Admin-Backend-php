import SwiftUI

/// Pendant zu Flutter `main_screen.dart` — Tab-Shell mit 5 Tabs + Profil-Avatar.
/// Die einzelnen Tab-Inhalte sind aktuell Platzhalter; sie werden Screen für
/// Screen aus dem Flutter-Code übersetzt (siehe TRANSLATION-GUIDE.md).
struct MainTabView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var selection = 0
    @State private var showProfile = false

    private struct Tab { let title: String; let icon: String }
    private let tabs = [
        Tab(title: "Start",     icon: "house.fill"),
        Tab(title: "Training",  icon: "dumbbell.fill"),
        Tab(title: "Kalender",  icon: "calendar"),
        Tab(title: "Chat",      icon: "bubble.left"),
        Tab(title: "Analytics", icon: "chart.line.uptrend.xyaxis"),
    ]

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    PlaceholderScreen(title: tab.title)
                        .tabItem { Label(tab.title, systemImage: tab.icon) }
                        .tag(index)
                }
                GlucoseView()
                    .tabItem { Label("Blutzucker", systemImage: "waveform.path.ecg") }
                    .tag(tabs.count)
            }
            .toolbarBackground(AppColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle(tabs[selection].title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Circle()
                            .fill(AppColor.primary)
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "person.fill").foregroundStyle(AppColor.white))
                    }
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                PlaceholderScreen(title: "Profil")
            }
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
