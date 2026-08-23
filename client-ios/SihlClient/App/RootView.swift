import SwiftUI

/// Auth-Gate — entspricht dem `Consumer<AuthProvider>` in `main.dart`:
/// authentifiziert → MainTabView, sonst LoginView.
struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isAuthenticated {
                if auth.clientId != nil {
                    MainTabView()
                } else {
                    // Alt-Session: clientId wird asynchron vom Server nachgeladen —
                    // Main-UI erst zeigen, wenn sie da ist, sonst laden alle Screens
                    // einmalig mit leerer ID ins Leere und retryen nie.
                    ProgressView().tint(AppColor.primary)
                }
            } else {
                LoginView()
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}
