import SwiftUI

/// Auth-Gate — entspricht dem `Consumer<AuthProvider>` in `main.dart`:
/// authentifiziert → MainTabView, sonst LoginView.
struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}
