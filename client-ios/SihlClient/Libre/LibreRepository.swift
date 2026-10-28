import Foundation

/// Cache-First Repository: frische Daten wenn >5min alt UND Token gültig,
/// sonst lokaler Cache (Offline-First). Pendant zu Flutter `libre_repository.dart`.
actor LibreRepository {
    private static let syncInterval: TimeInterval = 5 * 60

    private let storage = LibreStorageService()
    private var apiClient: LibreAPIClient?
    /// Steigt bei jedem Logout — ein Sync, der davor begonnen hat, darf
    /// danach nichts mehr zurückschreiben.
    private var generation = 0

    // MARK: - Auth

    var isLoggedIn: Bool {
        guard let ticket = storage.loadAuthTicket() else { return false }
        return !ticket.isExpired
    }

    func login(email: String, password: String, region: LibreRegion = .eu) async throws {
        let startedIn = generation
        let client = LibreAPIClient(region: region)
        let ticket = try await client.login(email: email, password: password)

        let connections = try await client.getConnections(token: ticket.token)
        guard let first = connections.first else {
            throw LibreError(code: 0, message: "Keine Libre-Verbindungen gefunden")
        }
        // Zwischenzeitlich abgemeldet → Zugang nicht speichern
        guard startedIn == generation else {
            throw LibreError(code: 0, message: "Anmeldung abgebrochen")
        }
        storage.saveAuth(email: email, ticket: ticket,
                         patientId: first.patientId, region: region)
        apiClient = client
    }

    func logout() {
        generation += 1
        storage.clearAuth()
        storage.clearReadings()
        apiClient = nil
    }

    // MARK: - Readings (Cache-First)

    func getReadings(forceRefresh: Bool = false) async -> LibreResult {
        let cached = storage.loadReadings()
        let lastSync = storage.loadLastSync()
        let needsSync = forceRefresh
            || lastSync.map { Date().timeIntervalSince($0) > Self.syncInterval } ?? true

        guard needsSync else {
            return LibreResult(readings: cached, fromCache: true, lastSync: lastSync)
        }

        let startedIn = generation
        do {
            let fresh = try await fetchFresh()
            // Während des Syncs getrennt → Daten verwerfen statt zurückschreiben
            guard startedIn == generation else {
                return LibreResult(readings: [], fromCache: false, lastSync: nil, needsReauth: true)
            }
            storage.saveReadings(fresh)
            return LibreResult(readings: fresh, fromCache: false, lastSync: Date())
        } catch let e as LibreError {
            guard startedIn == generation else {
                return LibreResult(readings: [], fromCache: false, lastSync: nil, needsReauth: true)
            }
            if e.code == 401 { storage.clearAuth() }
            return LibreResult(readings: cached, fromCache: true,
                               lastSync: lastSync, error: e.message,
                               needsReauth: e.code == 401)
        } catch {
            guard startedIn == generation else {
                return LibreResult(readings: [], fromCache: false, lastSync: nil, needsReauth: true)
            }
            return LibreResult(readings: cached, fromCache: true,
                               lastSync: lastSync,
                               error: "Keine Verbindung — lokale Daten werden angezeigt")
        }
    }

    private func fetchFresh() async throws -> [GlucoseReading] {
        guard let ticket = storage.loadAuthTicket(), !ticket.isExpired,
              let patientId = storage.loadPatientId() else {
            throw LibreError(code: 401, message: "Bitte erneut einloggen")
        }
        let region = storage.loadRegion()
        let client = apiClient ?? LibreAPIClient(region: region)
        apiClient = client
        return try await client.getGraphData(token: ticket.token, patientId: patientId)
    }
}

struct LibreResult {
    let readings: [GlucoseReading]
    let fromCache: Bool
    let lastSync: Date?
    var error: String? = nil
    /// Zugang ungültig (401) oder abgemeldet → neu einloggen
    var needsReauth = false

    var latest: GlucoseReading? { readings.last }
}
