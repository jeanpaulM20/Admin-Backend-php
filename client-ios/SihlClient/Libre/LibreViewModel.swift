import Foundation
import Observation

/// Pendant zu Flutter `libre_provider.dart` — @Observable statt ChangeNotifier.
@MainActor
@Observable
final class LibreViewModel {
    private let repo = LibreRepository()

    private(set) var readings: [GlucoseReading] = []
    private(set) var isLoggedIn = false
    private(set) var isLoading = false
    private(set) var fromCache = false
    private(set) var lastSync: Date? = nil
    var error: String? = nil

    var latestReading: GlucoseReading? { readings.last }

    init() {
        Task { await initialize() }
    }

    private func initialize() async {
        isLoggedIn = await repo.isLoggedIn
        if isLoggedIn { await loadReadings() }
    }

    // MARK: - Auth

    @discardableResult
    func login(email: String, password: String, region: LibreRegion = .eu) async -> Bool {
        isLoading = true
        error = nil
        do {
            try await repo.login(email: email, password: password, region: region)
            isLoggedIn = true
            await loadReadings()
            isLoading = false
            return true
        } catch {
            self.error = (error as? LibreError)?.message ?? error.localizedDescription
            isLoading = false
            return false
        }
    }

    func logout() async {
        await repo.logout()
        readings = []
        isLoggedIn = false
        lastSync = nil
        error = nil
    }

    // MARK: - Daten laden

    func loadReadings(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil
        let result = await repo.getReadings(forceRefresh: forceRefresh)
        readings = result.readings
        fromCache = result.fromCache
        lastSync = result.lastSync
        if let e = result.error { error = e }
        if result.error?.contains("401") == true { isLoggedIn = false }
        isLoading = false
    }

    func clearError() { error = nil }
}
