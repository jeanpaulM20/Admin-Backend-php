import Foundation

/// Cache-First Repository: frische Daten wenn >5min alt UND Token gültig,
/// sonst lokaler Cache (Offline-First). Pendant zu Flutter `libre_repository.dart`.
actor LibreRepository {
    private static let syncInterval: TimeInterval = 5 * 60

    private let storage = LibreStorageService()
    private var apiClient: LibreAPIClient?

    // MARK: - Auth

    var isLoggedIn: Bool {
        guard let ticket = storage.loadAuthTicket() else { return false }
        return !ticket.isExpired
    }

    func login(email: String, password: String, region: LibreRegion = .eu) async throws {
        let client = LibreAPIClient(region: region)
        let ticket = try await client.login(email: email, password: password)

        let connections = try await client.getConnections(token: ticket.token)
        guard let first = connections.first else {
            throw LibreError(code: 0, message: "Keine Libre-Verbindungen gefunden")
        }
        storage.saveAuth(email: email, ticket: ticket,
                         patientId: first.patientId, region: region)
        apiClient = client
    }

    func logout() {
        storage.clearAuth()
        storage.clearReadings()
        apiClient = nil
    }

    // MARK: - Readings (Cache-First)

    func getReadings(forceRefresh: Bool = false) async -> LibreResult {
        let cached = storage.loadReadings()
        let lastSync = storage.loadLastSync()
        let needsSync = forceRefresh
            || lastSync == nil
            || Date().timeIntervalSince(lastSync!) > Self.syncInterval

        guard needsSync else {
            return LibreResult(readings: cached, fromCache: true, lastSync: lastSync)
        }

        do {
            let fresh = try await fetchFresh()
            storage.saveReadings(fresh)
            return LibreResult(readings: fresh, fromCache: false, lastSync: Date())
        } catch let e as LibreError {
            if e.code == 401 { storage.clearAuth() }
            return LibreResult(readings: cached, fromCache: true,
                               lastSync: lastSync, error: e.message)
        } catch {
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

    var latest: GlucoseReading? { readings.last }
}
