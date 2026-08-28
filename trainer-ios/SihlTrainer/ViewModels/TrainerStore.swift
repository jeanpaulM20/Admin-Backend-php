import Foundation

/// Gemeinsamer Datenspeicher für Kunden und Termine.
/// Pendant zu `providers/trainer_provider.dart` (dort ChangeNotifier).
@MainActor
final class TrainerStore: ObservableObject {
    @Published private(set) var clients: [Client] = []
    @Published private(set) var clientsLoading = false
    @Published private(set) var clientsError: String?

    @Published private(set) var trainings: [Training] = []
    @Published private(set) var trainingsLoading = false
    @Published private(set) var trainingsError: String?

    private let service = TrainerDataService()

    /// Erstbefüllung nach dem Login.
    func load(trainerId: Int) async {
        async let clients: Void = loadClients()
        async let trainings: Void = loadTrainings(trainerId: trainerId)
        _ = await (clients, trainings)
    }

    func loadClients() async {
        clientsLoading = true
        clientsError = nil
        defer { clientsLoading = false }
        do {
            clients = try await service.clients()
        } catch let error as APIError {
            clientsError = error.message
        } catch {
            clientsError = "Kunden konnten nicht geladen werden"
        }
    }

    func loadTrainings(trainerId: Int) async {
        trainingsLoading = true
        trainingsError = nil
        defer { trainingsLoading = false }
        do {
            trainings = try await service.trainings(trainerId: trainerId)
        } catch let error as APIError {
            trainingsError = error.message
        } catch {
            trainingsError = "Termine konnten nicht geladen werden"
        }
    }

    #if DEBUG
    /// Beispieldaten statt Netzwerk — nur im Vorschaumodus.
    func loadPreviewData() {
        clients = PreviewData.clients
        trainings = PreviewData.trainings
        clientsError = nil
        trainingsError = nil
    }
    #endif

    // MARK: - Abgeleitete Werte für die Übersicht

    /// Nicht abgesagte Termine ab jetzt, aufsteigend.
    var upcoming: [Training] {
        let now = Date()
        return trainings
            .filter { !$0.isCancelled && ($0.startTime ?? .distantPast) >= now }
            .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }

    var nextTraining: Training? { upcoming.first }

    var todayCount: Int {
        trainings.filter { training in
            guard let start = training.startTime, !training.isCancelled else { return false }
            return Calendar.current.isDateInToday(start)
        }.count
    }

    var thisWeekCount: Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return trainings.filter { training in
            guard let start = training.startTime, !training.isCancelled else { return false }
            return week.contains(start)
        }.count
    }
}
