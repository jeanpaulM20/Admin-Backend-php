import Foundation

/// Zentrale Aufräum-Routine beim Logout — damit nach einem Kontowechsel
/// keine Daten des vorigen Kontos auf dem Gerät bleiben.
///
/// Bewusst NICHT gelöscht: `Documents/pending-workouts` und
/// die Snapshots in Application Support/active-workouts und Documents/active-photos
/// (gehören dem Konto, werden per clientId zugeordnet)
/// sowie geräteweite Einstellungen (Brustgurt, Sprachhinweise).
/// Die Daten-ViewModels und Libre setzt `SihlClientApp` neu auf.
enum SessionCleanup {

    /// Nutzerbezogene UserDefaults-Schlüssel anderer Module.
    private static let userDefaultsKeys = [
        "startChipPlansFirst",   // StartChip: Reihenfolge nach Nutzung
        "lastStartChip",         // StartChip: Vorgänger-Schlüssel
        "lastWorkoutActivity",   // WorkoutRecorder: zuletzt genutzte Aktivität
        TourAssistantConsent.storageKey,  // KI-Einwilligung ist persönlich
    ]
    /// Präfixe nutzerbezogener Schlüssel (z. B. Abo-Ablauf-Hinweis je Datum).
    private static let userDefaultsPrefixes = ["expiry_popup_"]

    /// Schritte, die noch die gültige Sitzung brauchen — VOR dem Löschen
    /// des Tokens ausführen.
    static func beforeTokenRemoval(clientId: String?) async {
        await PushNotificationService.shared.logoutCleanup(clientId: clientId)
    }

    /// Lokale Spuren entfernen — NACH dem Löschen des Tokens.
    static func afterTokenRemoval() async {
        URLCache.shared.removeAllCachedResponses()
        await WorkoutPhotoService.shared.clearCache()
        await TokenImageStore.shared.removeAll()
        ProfileService.clearDownloadedFiles()
        clearTemporaryFiles()
        removeUserDefaults()
    }

    /// Temporäre Dateien (heruntergeladene Termine .ics, Vorschauen) des
    /// vorigen Kontos entfernen.
    private static func clearTemporaryFiles() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let items = (try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
        items.forEach { try? fm.removeItem(at: $0) }
    }

    private static func removeUserDefaults() {
        let ud = UserDefaults.standard
        userDefaultsKeys.forEach { ud.removeObject(forKey: $0) }
        for key in ud.dictionaryRepresentation().keys
        where userDefaultsPrefixes.contains(where: { key.hasPrefix($0) }) {
            ud.removeObject(forKey: key)
        }
    }
}
