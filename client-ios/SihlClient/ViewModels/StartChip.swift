import Foundation

// MARK: - StartChip

/// Die Reihe auf der Startseite: „Trainingspläne" und die Aktivitäten.
/// „Trainingspläne" verhält sich wie eine Aktivität — wer die Pläne zuletzt
/// geöffnet hat, sieht sie vorne. Die zuletzt GESTARTETE Aktivität bleibt
/// dabei immer gleich dahinter sichtbar, denn sie ist vorgewählt und
/// „Training starten" startet genau sie.
///
/// Gespeichert werden zwei getrennte Fakten, jeder an einem Ort:
/// - welche Aktivität zuletzt gestartet wurde (`WorkoutActivity.lastUsed`)
/// - ob die Pläne danach noch geöffnet wurden (`plansFirst`)
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

    /// Pläne nach der letzten gestarteten Aktivität geöffnet?
    static var plansFirst: Bool {
        let defaults = UserDefaults.standard
        if let legacy = defaults.string(forKey: legacyKey) {
            defaults.set(legacy == "plans", forKey: plansFirstKey)
            defaults.removeObject(forKey: legacyKey)
        }
        return defaults.bool(forKey: plansFirstKey)
    }

    /// Pläne geöffnet — zählt als Nutzung.
    static func noteOpenedPlans() {
        UserDefaults.standard.set(true, forKey: plansFirstKey)
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
