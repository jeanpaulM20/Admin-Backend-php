import SwiftUI

/// App-Einstiegspunkt — Pendant zu Flutter `main.dart`.
/// In Flutter wurden alle Provider per `MultiProvider` registriert; in SwiftUI
/// werden ViewModels per `.environment(...)` injiziert. Weitere ViewModels
/// (Appointment, Profile, Credits, ...) hier ergänzen, sobald übersetzt.
@main
struct SihlClientApp: App {
    @State private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
        }
    }
}
