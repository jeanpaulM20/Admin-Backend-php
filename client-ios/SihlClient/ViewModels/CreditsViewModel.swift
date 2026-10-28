import Foundation

/// Pendant zu `CreditsProvider` — lädt Lektionen-Guthaben und -Pakete (Training vor Ort).
@MainActor @Observable final class CreditsViewModel {
    var credits:  [ClientCredit]  = []
    var packages: [CreditPackage] = []
    var isLoading = false
    var error: String?

    /// Summe der aktuell verfügbaren Lektionen über alle Pakete.
    var activeCredits: Int {
        credits.filter(\.isActive).reduce(0) { $0 + $1.remaining }
    }

    /// Anzahl aktiver Pakete
    var activePackCount: Int { credits.filter(\.isActive).count }

    func fetch(clientId: String) async {
        isLoading = true
        error     = nil
        do {
            async let creds = CreditsService.shared.listClientCredits(clientId: clientId)
            async let pkgs  = CreditsService.shared.listPackages()
            (credits, packages) = try await (creds, pkgs)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
