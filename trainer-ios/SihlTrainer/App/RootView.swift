import SwiftUI

/// Entscheidet zwischen Login und App. Beim Start wird zuerst versucht, die
/// gespeicherte Sitzung wiederherzustellen — solange läuft der Startbildschirm.
struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if auth.isRestoring {
                SplashView()
            } else if auth.isLoggedIn {
                MainView()
            } else {
                LoginView()
            }
        }
        .task {
            #if DEBUG
            // Startargument -preview: öffnet den Vorschaumodus direkt. Dient
            // dem automatisierten Prüfen der angemeldeten Ansichten.
            if ProcessInfo.processInfo.arguments.contains("-preview") {
                auth.startPreview()
                return
            }
            #endif
            await auth.restoreSession()
        }
    }
}

private struct SplashView: View {
    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            BrandMark()
            ProgressView().tint(AppColor.primary)
        }
    }
}

/// Logo-Kachel — Hantel auf Marken-Olive, wie im Flutter-Login.
struct BrandMark: View {
    var size: CGFloat = 72

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .fill(AppColor.primary)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "dumbbell.fill")
                    .font(.app(size * 0.42, weight: .semibold))
                    .foregroundStyle(AppColor.white)
            )
    }
}
