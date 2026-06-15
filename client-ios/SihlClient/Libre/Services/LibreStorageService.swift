import Foundation

/// Lokale Persistenz für Libre-Daten (Offline-First, kein Backend).
/// Token → Keychain (sicher), Readings → JSON-Datei im Documents-Verzeichnis.
struct LibreStorageService {
    private enum Keys {
        static let token     = "libre_token"       // Keychain
        static let expires   = "libre_expires"     // UserDefaults (ms)
        static let email     = "libre_email"       // UserDefaults
        static let patientId = "libre_patient_id"  // UserDefaults
        static let region    = "libre_region"      // UserDefaults
        static let lastSync  = "libre_last_sync"   // UserDefaults
    }

    private let readingsFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("libre_readings.json")
    }()

    // MARK: - Auth

    func saveAuth(email: String, ticket: LibreAuthTicket,
                  patientId: String, region: LibreRegion) {
        KeychainStore.set(ticket.token, for: Keys.token)
        let ud = UserDefaults.standard
        ud.set(Int(ticket.expires.timeIntervalSince1970 * 1000), forKey: Keys.expires)
        ud.set(email, forKey: Keys.email)
        ud.set(patientId, forKey: Keys.patientId)
        ud.set(region.rawValue, forKey: Keys.region)
    }

    func loadAuthTicket() -> LibreAuthTicket? {
        guard let token = KeychainStore.get(Keys.token),
              !token.isEmpty else { return nil }
        let ms = UserDefaults.standard.integer(forKey: Keys.expires)
        let expires = ms > 0
            ? Date(timeIntervalSince1970: Double(ms) / 1000)
            : Date().addingTimeInterval(60 * 60 * 24 * 180)
        return LibreAuthTicket(token: token, expires: expires)
    }

    func loadEmail() -> String?     { UserDefaults.standard.string(forKey: Keys.email) }
    func loadPatientId() -> String? { UserDefaults.standard.string(forKey: Keys.patientId) }

    func loadRegion() -> LibreRegion {
        guard let raw = UserDefaults.standard.string(forKey: Keys.region),
              let region = LibreRegion(rawValue: raw) else { return .eu }
        return region
    }

    func clearAuth() {
        KeychainStore.remove(Keys.token)
        [Keys.expires, Keys.email, Keys.patientId, Keys.region]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Readings (JSON-Datei im Documents-Verzeichnis)

    func saveReadings(_ readings: [GlucoseReading]) {
        guard let data = try? JSONEncoder().encode(readings) else { return }
        try? data.write(to: readingsFile, options: .atomic)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastSync)
    }

    func loadReadings() -> [GlucoseReading] {
        guard let data = try? Data(contentsOf: readingsFile),
              let readings = try? JSONDecoder().decode([GlucoseReading].self, from: data)
        else { return [] }
        return readings
    }

    func loadLastSync() -> Date? {
        let ts = UserDefaults.standard.double(forKey: Keys.lastSync)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    func clearReadings() {
        try? FileManager.default.removeItem(at: readingsFile)
        UserDefaults.standard.removeObject(forKey: Keys.lastSync)
    }
}
