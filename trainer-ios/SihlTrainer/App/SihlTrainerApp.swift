import SwiftUI

@main
struct SihlTrainerApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var store = TrainerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
        }
    }
}
