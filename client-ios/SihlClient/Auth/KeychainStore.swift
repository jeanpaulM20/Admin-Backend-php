import Foundation
import UIKit
import OSLog
import Security

/// Sichere Token-Speicherung in der iOS-Keychain.
/// Ersetzt Flutter `SharedPreferences` für sensible Werte (Auth-Token).
/// Nicht-sensible Prefs liegen weiterhin in `UserDefaults`.
///
/// Einträge sind nur auf diesem Gerät und erst nach dem ersten Entsperren
/// lesbar (`…AfterFirstUnlockThisDeviceOnly`) — sie wandern weder in
/// Backups noch auf ein neues Gerät.
enum KeychainStore {
    private static let service = "ch.sihltraining.client"
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    private static let log = Logger(subsystem: "ch.sihltraining.SihlClient", category: "Keychain")

    /// Stand der Keychain-Einträge (1 = auf ThisDeviceOnly umgestellt).
    private static let versionKey = "keychain_store_version"
    private static let currentVersion = 1

    /// UserDefaults-Schlüssel, die nur eine schon benutzte Installation hat.
    /// Fehlen alle, ist die App frisch installiert.
    private static let existingInstallKeys = [
        "client_id", "sihl_apns_token", "libre_patient_id", "libre_email",
        "lastWorkoutActivity", "routeVoiceEnabled",
        "hr_peripheral_uuid", "startChipPlansFirst",
    ]

    /// Läuft genau einmal vor dem ersten Keychain-Zugriff. Die Keychain
    /// überlebt das Löschen der App, UserDefaults nicht: Nach einer
    /// Neuinstallation werden alte Einträge entfernt, damit niemand
    /// automatisch angemeldet ist. Bestehende Installationen werden
    /// stattdessen auf die neue Zugänglichkeit umgestellt.
    private static let installCheck: Void = {
        let ud = UserDefaults.standard
        guard ud.integer(forKey: versionKey) < currentVersion else { return }
        // Vor dem ersten Entsperren sind UserDefaults und Keychain nicht
        // lesbar — dann nicht entscheiden (sonst würde fälschlich gelöscht),
        // sondern beim nächsten Start erneut prüfen
        guard Self.protectedDataAvailable else { return }
        let isExistingInstall = existingInstallKeys.contains { ud.object(forKey: $0) != nil }
        if isExistingInstall {
            migrateAccessibility()
        } else {
            removeAll()
        }
        ud.set(currentVersion, forKey: versionKey)
    }()

    /// Geschützte Daten verfügbar (Gerät seit dem Start einmal entsperrt)?
    private static var protectedDataAvailable: Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { UIApplication.shared.isProtectedDataAvailable }
        }
        return DispatchQueue.main.sync { UIApplication.shared.isProtectedDataAvailable }
    }

    // MARK: - Öffentlich

    @discardableResult
    static func set(_ value: String?, for key: String) -> Bool {
        _ = installCheck
        guard let value, !value.isEmpty else {
            remove(key)
            return true
        }
        let data = Data(value.utf8)
        let query = baseQuery(key)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes.merge(update) { _, new in new }
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            log.error("Schreiben fehlgeschlagen (\(key, privacy: .public)): \(status, privacy: .public)")
            return false
        }
        return true
    }

    static func get(_ key: String) -> String? {
        _ = installCheck
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        _ = installCheck
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    // MARK: - Intern

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    /// Alle Einträge dieser App löschen.
    private static func removeAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Vorhandene Einträge auf `…ThisDeviceOnly` umstellen.
    private static func migrateAccessibility() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let update: [String: Any] = [kSecAttrAccessible as String: accessibility]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            log.error("Migration fehlgeschlagen: \(status, privacy: .public)")
        }
    }
}
