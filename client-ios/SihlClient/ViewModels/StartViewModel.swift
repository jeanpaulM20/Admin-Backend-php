import Foundation

/// Pendant zu `appointment_provider.dart` (Start-Teil): liefert die Stammdaten
/// für die Avatar-Initialen in der Tab-Leiste.
///
/// Termin-Daten laden blockierend (`isLoading`); das Tageszitat lädt wie in
@MainActor @Observable
final class StartViewModel {

    var isLoading   = false
    var error: String?
    var startData: StartData?

    private let service = AppointmentService()

    // MARK: - Public

    func load(clientId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error     = nil

        do {
            startData = try await service.getStartData(clientId: clientId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

}
