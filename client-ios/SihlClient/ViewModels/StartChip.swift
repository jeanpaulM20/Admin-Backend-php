import Foundation

// MARK: - StartChip

/// Die Reihe auf der Startseite: „Trainingspläne" und die Aktivitäten.
/// „Trainingspläne" ist ein Reiter wie die Aktivitäten: antippen wählt ihn
/// (grün hervorgehoben) und zeigt die Pläne darunter. Wer zuletzt die Pläne
/// gewählt hat, sieht sie vorne — und beim nächsten Öffnen wieder gewählt.
/// Die vorgewählte Aktivität bleibt dabei immer gleich dahinter sichtbar.
///
/// Gespeichert werden zwei getrennte Fakten, jeder an einem Ort:
/// - welche Aktivität zuletzt gestartet wurde (`WorkoutActivity.lastUsed`)
/// - ob danach die Pläne der gewählte Reiter waren (`plansFirst`)
enum StartChip: Hashable, Identifiable {
    case plans
    case activity(WorkoutActivity)

    var id: String {
        switch self {
        case .plans:           return "plans"
        case .activity(let a): return a.rawValue
        }
    }

    /// Stammreihenfolge: Pläne zuerst, dann die Aktivitäten wie definiert.
    static let defaultOrder: [StartChip] = [.plans] + WorkoutActivity.allCases.map(StartChip.activity)

    // MARK: Nutzung merken

    private static let plansFirstKey = "startChipPlansFirst"
    /// Vorgänger-Schlüssel (Commit 4e05d53d) — nur noch zur Übernahme gelesen
    private static let legacyKey = "lastStartChip"

    private static let migratedKey = "startChipMigrated"

    /// Pläne nach der letzten gestarteten Aktivität gewählt?
    static var plansFirst: Bool {
        let defaults = UserDefaults.standard
        // Bisherigen Schlüssel genau einmal übernehmen — nie erneut, sonst
        // überschriebe ein nicht löschbarer Altwert jede spätere Wahl
        if !defaults.bool(forKey: migratedKey) {
            if let legacy = defaults.string(forKey: legacyKey) {
                defaults.set(legacy == "plans", forKey: plansFirstKey)
                defaults.removeObject(forKey: legacyKey)
            }
            defaults.set(true, forKey: migratedKey)
        }
        return defaults.bool(forKey: plansFirstKey)
    }

    /// Pläne gewählt — zählt als Nutzung (dort wird nichts „gestartet").
    static func noteSelectedPlans() {
        UserDefaults.standard.set(true, forKey: plansFirstKey)
    }

    /// Von den Plänen zurück auf eine Aktivität gewechselt — die Pläne geben
    /// den ersten Platz wieder ab. Die Aktivität selbst zählt erst beim Start.
    static func noteSelectedActivity() {
        UserDefaults.standard.set(false, forKey: plansFirstKey)
    }

    /// Aufzeichnung gestartet — die Aktivität wird vorgewählt und rückt nach vorne.
    static func noteStarted(_ activity: WorkoutActivity) {
        WorkoutActivity.rememberUsed(activity)
        UserDefaults.standard.set(false, forKey: plansFirstKey)
    }

    // MARK: Reihenfolge

    /// Reihenfolge aus dem gespeicherten Stand.
    /// - `selected`: die vorgewählte Aktivität (Standard: zuletzt gestartet,
    ///   oder was seither angetippt wurde) — sie bleibt immer sichtbar.
    /// - `routeActivity`: Aktivität einer übergebenen Route — sie steht ganz
    ///   vorne, bis die Route gestartet oder entfernt ist.
    static func ordered(selected: WorkoutActivity?, routeActivity: WorkoutActivity? = nil) -> [StartChip] {
        order(plansFirst: plansFirst, selected: selected, routeActivity: routeActivity)
    }

    /// Reine Sortierregel (ohne Speicher):
    /// - Route übergeben → ihre Aktivität vorne, Rest in Stammreihenfolge
    /// - Pläne zuletzt genutzt → Pläne, dann die vorgewählte Aktivität
    /// - sonst → vorgewählte Aktivität, dann Pläne an ihrem Stammplatz
    static func order(plansFirst: Bool, selected: WorkoutActivity?,
                      routeActivity: WorkoutActivity?) -> [StartChip] {
        var front: [StartChip] = []
        if let routeActivity {
            front = [.activity(routeActivity)]
        } else if plansFirst {
            front = [.plans] + (selected.map { [.activity($0)] } ?? [])
        } else if let selected {
            front = [.activity(selected)]
        }
        return front + defaultOrder.filter { !front.contains($0) }
    }
}
