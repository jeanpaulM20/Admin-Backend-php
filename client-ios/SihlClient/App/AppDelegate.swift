import UIKit

/// UIApplicationDelegate — empfängt APNs-Callbacks, die in reinen SwiftUI-Apps
/// nicht über `@main` erreichbar sind.
/// Wird in `SihlClientApp` via `@UIApplicationDelegateAdaptor` eingebunden.
class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await PushNotificationService.shared.updateDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Benachrichtigungen auch im Vordergrund anzeigen
        completionHandler([.banner, .sound, .badge])
    }
}
