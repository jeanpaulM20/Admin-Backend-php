import SwiftUI

@main
struct SihlTrainerApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var store = TrainerStore()
    @StateObject private var chat = ChatStore()
    @StateObject private var calendarStore = CalendarStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(store)
                .environmentObject(chat)
                .environmentObject(calendarStore)
                .preferredColorScheme(.dark)
                .tint(AppColor.primary)
        }
    }
}
