import SwiftUI

/// App-Einstiegspunkt — Pendant zu Flutter `main.dart`.
/// In Flutter wurden alle Provider per `MultiProvider` registriert; in SwiftUI
/// werden ViewModels per `.environment(...)` injiziert. Weitere ViewModels
/// (Appointment, Profile, Credits, ...) hier ergänzen, sobald übersetzt.
///
/// Composition Root: verdrahtet den APIClient (401 → Logout) mit dem
/// AuthViewModel und setzt beim Logout alle Daten-ViewModels neu auf.
@main
struct SihlClientApp: App {
    // APNs-Callbacks kommen über UIApplicationDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var auth: AuthViewModel
    @State private var libre     = LibreViewModel()
    @State private var start     = StartViewModel()
    @State private var profile   = ProfileViewModel()
    @State private var calendar  = CalendarViewModel()
    @State private var training  = TrainingViewModel()
    @State private var chatVM    = ChatViewModel()
    @State private var analytics = AnalyticsViewModel()
    @State private var creditsVM = CreditsViewModel()
    @State private var launcher  = RecordingLauncher()

    init() {
        let auth = AuthViewModel()
        _auth = State(initialValue: auth)
        // Ungültige Sitzung (401 ausser Login) → zentral abmelden
        APIClient.shared.setUnauthorizedHandler {
            await auth.sessionExpired()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(libre)
                .environment(start)
                .environment(profile)
                .environment(calendar)
                .environment(training)
                .environment(chatVM)
                .environment(analytics)
                .environment(creditsVM)
                .environment(launcher)
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
                .onChange(of: auth.clientId, initial: true) { _, newId in
                    // APNs mit clientId konfigurieren — bei jedem Start und
                    // nach Login; nicht im Demo-Modus
                    if let id = newId, !id.isEmpty, id != AuthViewModel.demoClientId {
                        Task { await PushNotificationService.shared.configure(clientId: id) }
                    }
                }
                .onChange(of: auth.isAuthenticated) { _, loggedIn in
                    // Bei Logout alle Daten-ViewModels verwerfen, damit nach einem
                    // Account-Wechsel keine Daten des vorherigen Users angezeigt werden.
                    // Caches, Push und UserDefaults räumt `SessionCleanup` auf.
                    if !loggedIn {
                        start     = StartViewModel()
                        profile   = ProfileViewModel()
                        calendar  = CalendarViewModel()
                        training  = TrainingViewModel()
                        chatVM    = ChatViewModel()
                        analytics = AnalyticsViewModel()
                        creditsVM = CreditsViewModel()
                        launcher  = RecordingLauncher()
                        // Libre-Zugang (Keychain, UserDefaults, Messwerte) gehört
                        // zum Konto — abmelden, dann frisch aufsetzen
                        let oldLibre = libre
                        Task {
                            await oldLibre.logout()
                            libre = LibreViewModel()
                        }
                    }
                }
        }
    }
}
