import SwiftUI

/// App-Einstiegspunkt — Pendant zu Flutter `main.dart`.
/// In Flutter wurden alle Provider per `MultiProvider` registriert; in SwiftUI
/// werden ViewModels per `.environment(...)` injiziert. Weitere ViewModels
/// (Appointment, Profile, Credits, ...) hier ergänzen, sobald übersetzt.
@main
struct SihlClientApp: App {
    @State private var auth    = AuthViewModel()
    @State private var libre   = LibreViewModel()
    @State private var start   = StartViewModel()
    @State private var profile = ProfileViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(libre)
                .environment(start)
                .environment(profile)
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
        }
    }
}
