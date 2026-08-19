import SwiftUI

/// App-Einstiegspunkt — Pendant zu Flutter `main.dart`.
/// In Flutter wurden alle Provider per `MultiProvider` registriert; in SwiftUI
/// werden ViewModels per `.environment(...)` injiziert. Weitere ViewModels
/// (Appointment, Profile, Credits, ...) hier ergänzen, sobald übersetzt.
@main
struct SihlClientApp: App {
    @State private var auth      = AuthViewModel()
    @State private var libre     = LibreViewModel()
    @State private var start     = StartViewModel()
    @State private var profile   = ProfileViewModel()
    @State private var calendar  = CalendarViewModel()
    @State private var training  = TrainingViewModel()
    @State private var chatVM    = ChatViewModel()
    @State private var analytics = AnalyticsViewModel()
    @State private var creditsVM = CreditsViewModel()

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
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
        }
    }
}
