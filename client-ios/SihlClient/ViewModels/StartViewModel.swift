import Foundation

/// Kombiniert `appointment_provider.dart` (Start-Teil) + `daily_quote_provider.dart`.
///
/// Termin-Daten laden blockierend (`isLoading`); das Tageszitat lädt wie in
/// Flutter (start_screen.dart:34 / daily_quote_provider.dart) NON-BLOCKING
/// parallel dazu mit eigenem `quoteLoading`-Flag (→ QuoteShimmer in StartView).
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

        // Zitat unabhängig & non-blocking starten (analog zu Flutter: quote.load())
        loadQuote()

        do {
            startData = try await service.getStartData(clientId: clientId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Daily Quote

    /// Idempotent — überspringt, wenn bereits geladen oder gerade am Laden
    /// (Pendant zu `DailyQuoteProvider.load()`).
    private func loadQuote() {
        guard !quoteLoading, quote == nil else { return }
        quoteLoading = true
        Task {
            // Quote-Fehler ist nicht kritisch — still ignorieren (silent fail)
            if let q = try? await DailyQuoteService.shared.fetch() {
                quote = q
            }
            quoteLoading = false
        }
    }
}
