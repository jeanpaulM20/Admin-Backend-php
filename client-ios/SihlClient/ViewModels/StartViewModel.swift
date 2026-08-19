import Foundation

/// Kombiniert `appointment_provider.dart` (Start-Teil) + `daily_quote_provider.dart`.
///
/// Gleichzeitiger Ladepfad: Start-Daten und Quote werden parallel geladen;
/// ein Quote-Fehler ist nicht fatal (silent fail wie in Flutter).
@MainActor @Observable
final class StartViewModel {

    var isLoading   = false
    var error: String?
    var startData: StartData?
    var quote: DailyQuote?
    var quoteLoading = false

    private let service = AppointmentService()

    // MARK: - Public

    func load(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error     = nil

        // Beide Requests gleichzeitig starten (analog zu Flutter: fetchStart + quote.load())
        async let startTask = service.getStartData(clientId: clientId)
        async let quoteTask = DailyQuoteService.shared.fetch()

        do {
            startData = try await startTask
        } catch {
            self.error = error.localizedDescription
        }

        // Quote-Fehler ist nicht kritisch — still ignorieren
        if let q = try? await quoteTask {
            quote = q
        }

        isLoading = false
    }
}
