import SwiftUI

/// Avatar oben rechts, der die Einstellungen öffnet. Liegt auf jedem
/// Bereichs-Root, damit das Konto von überall erreichbar ist — den Tab-Platz
/// braucht die App für die fünf Arbeitsbereiche.
struct ProfileToolbar: ViewModifier {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Avatar(initials: auth.trainer?.initials ?? "?",
                               photo: auth.trainer?.photo,
                               size: 30)
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}

extension View {
    /// Einheitlicher Kopfbereich aller Bereichs-Roots.
    func sectionChrome(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .background(AppColor.background)
            .toolbarBackground(AppColor.background, for: .navigationBar)
            .modifier(ProfileToolbar())
    }
}
