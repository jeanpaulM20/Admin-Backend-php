import OSLog
import UIKit
import UserNotifications

/// UIApplicationDelegate — empfängt APNs-Callbacks, die in reinen SwiftUI-Apps
/// nicht über `@main` erreichbar sind.
/// Wird in `SihlClientApp` via `@UIApplicationDelegateAdaptor` eingebunden.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private static let log = Logger(subsystem: "ch.sihltraining.SihlClient", category: "APNs")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Muss vor Ende des Starts gesetzt sein, sonst gehen Banner im
        // Vordergrund und Taps auf Mitteilungen verloren
        UNUserNotificationCenter.current().delegate = self
        // Die APNs-Registrierung bei jedem Start übernimmt
        // `PushNotificationService.configure(clientId:)`, sobald die
        // clientId feststeht (SihlClientApp).
        return true
    }

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
        Self.log.error("Registrierung fehlgeschlagen: \(error.localizedDescription, privacy: .private)")
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Benachrichtigungen auch im Vordergrund anzeigen
        completionHandler([.banner, .list, .sound, .badge])
    }
}
