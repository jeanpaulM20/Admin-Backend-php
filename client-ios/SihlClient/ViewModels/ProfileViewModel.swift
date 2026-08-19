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

    var polarConnected  = false
    var polarConnectUrl: String?
    var polarLoading    = false

    private let service = ProfileService()

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
            polarConnected  = polar.connected
            polarConnectUrl = polar.connectUrl
        }

        isLoading = false
    }

    // MARK: - Polar

    func syncPolar(clientId: String) async throws {
        polarLoading = true
        defer { polarLoading = false }
        try await service.syncPolar(clientId: clientId)
        if let p = try? await service.getPolarStatus(clientId: clientId) {
            polarConnected = p.connected
        }
    }

    func disconnectPolar(clientId: String) async throws {
        polarLoading = true
        defer { polarLoading = false }
        try await service.disconnectPolar(clientId: clientId)
        polarConnected = false
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
