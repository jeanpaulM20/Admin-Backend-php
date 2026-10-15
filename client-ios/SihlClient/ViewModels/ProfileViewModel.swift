import Foundation

/// Pendant zu `providers/profile_provider.dart` (inkl. Polar-State aus dem Screen).
/// Alle drei Requests (Profil, Rechnungen, Dateien) laufen parallel; Polar separat.
@MainActor @Observable
final class ProfileViewModel {

    // MARK: - State

    var isLoading    = false
    var error: String?

    var data: ProfileData?
    var invoices: [Invoice]    = []
    var files: [ClientFile]    = []

    var polarAvailable  = true
    var polarConnected  = false
    var polarConnectUrl: String?
    var polarLastSync: Date?
    var polarLoading    = false

    private let service = ProfileService()
    private let polarAuth = PolarAuthSession()

    // MARK: - Laden

    func load(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error     = nil

        // Parallel: Profil + Rechnungen + Dateien + Polar-Status
        async let profileTask  = service.getProfile(clientId: clientId)
        async let invoicesTask = service.getInvoices(clientId: clientId)
        async let filesTask    = service.getFiles(clientId: clientId)
        async let polarTask    = service.getPolarStatus(clientId: clientId)

        do {
            data = try await profileTask
        } catch {
            self.error = error.localizedDescription
        }

        // Nicht kritisch — silent fail
        invoices           = (try? await invoicesTask) ?? invoices
        files              = (try? await filesTask)    ?? files
        if let polar = try? await polarTask {
            apply(polar)
        }

        isLoading = false
    }

    // MARK: - Polar

    /// Öffnet die Polar-Anmeldung; danach den Status neu laden.
    /// Liefert nil bei Erfolg oder Abbruch, sonst die Fehlermeldung.
    func connectPolar(clientId: String) async -> String? {
        guard let raw = polarConnectUrl, let url = URL(string: raw) else {
            return "Polar-Verbindung ist gerade nicht verfügbar"
        }
        let outcome = await polarAuth.start(url: url)
        polarLoading = true
        defer { polarLoading = false }
        // Auch nach Abbruch neu laden: Der state im Link gilt nur 10 Minuten
        if let p = try? await service.getPolarStatus(clientId: clientId) { apply(p) }
        switch outcome {
        case .connected, .cancelled: return nil
        case .failed(let message):   return message
        }
    }

    /// Liefert die Meldung des Servers (z. B. „2 Polar-Trainings importiert").
    func syncPolar(clientId: String) async throws -> String {
        polarLoading = true
        defer { polarLoading = false }
        do {
            let message = try await service.syncPolar(clientId: clientId)
            if let p = try? await service.getPolarStatus(clientId: clientId) { apply(p) }
            return message
        } catch {
            // Abgelaufene Verbindung trennt der Server selbst → Status nachziehen
            if let p = try? await service.getPolarStatus(clientId: clientId) { apply(p) }
            throw error
        }
    }

    private func apply(_ status: PolarStatus) {
        polarAvailable  = status.available
        polarConnected  = status.connected
        polarConnectUrl = status.connectUrl
        polarLastSync   = status.lastSyncAt
    }

    func disconnectPolar(clientId: String) async throws {
        polarLoading = true
        defer { polarLoading = false }
        try await service.disconnectPolar(clientId: clientId)
        polarConnected = false
        // Neuer Verbinden-Link für den getrennten Zustand
        if let p = try? await service.getPolarStatus(clientId: clientId) { apply(p) }
    }

    // MARK: - Helpers

    var activePacks:  [CreditPack] { data?.creditPacks.filter { !$0.isExpired } ?? [] }
    var expiredPacks: [CreditPack] { data?.creditPacks.filter {  $0.isExpired } ?? [] }

    var creditsSubtitle: String {
        let active = activePacks
        if active.isEmpty { return "Keine aktiven Credits" }
        return countLabel(active.count, "aktives Paket", "aktive Pakete")
    }

    func countLabel(_ n: Int, _ singular: String, _ plural: String) -> String {
        n == 0 ? "Keine \(plural)" : "\(n) \(n == 1 ? singular : plural)"
    }
}
