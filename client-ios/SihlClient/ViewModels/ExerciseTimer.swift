import Foundation

/// Trainings-Timer — Stopwatch- und Countdown-Modus.
/// Pendant zu `providers/exercise_timer.dart`.
///
/// Die Zeit wird aus Start-/Endzeitpunkten (`Date`) berechnet, nicht pro Tick
/// gezählt: Scrollen, gesperrter Bildschirm oder ein verpasster Tick verfälschen
/// sie nicht. Der Ticker aktualisiert nur die Anzeige.
@MainActor @Observable
final class ExerciseTimer {

    // ── Öffentlicher State ─────────────────────────────────────────────────
    var display   = "00:00"
    var isRunning = false
    var isCountdown     = false
    var countdownFrom   = 0
    var countdownRemaining = 0

    /// Welche Übung gerade aktiv ist (nil = Stopwatch-Modus).
    var activePrefix: String?
    var activeIndex:  Int?
    var activeName = ""

    // ── Intern ────────────────────────────────────────────────────────────
    @ObservationIgnored private var ticker: Timer?
    /// Stopwatch: abgeschlossene Laufzeit vor dem aktuellen Abschnitt
    @ObservationIgnored private var accumulated: TimeInterval = 0
    /// Stopwatch: Start des laufenden Abschnitts
    @ObservationIgnored private var startedAt: Date?
    /// Countdown: Endzeitpunkt, solange er läuft
    @ObservationIgnored private var endsAt: Date?
    /// Countdown: Restzeit im Pausenzustand
    @ObservationIgnored private var pausedRemaining: TimeInterval = 0

    // ── Steuerung ─────────────────────────────────────────────────────────

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        if isCountdown && countdownRemaining <= 0 { reset(); return }
        let now = Date()
        if isCountdown {
            endsAt = now.addingTimeInterval(pausedRemaining)
        } else {
            startedAt = now
        }
        isRunning = true
        startTicker()
        refresh()
    }

    func pause() {
        guard isRunning else { return }
        let now = Date()
        if isCountdown, let end = endsAt {
            pausedRemaining = max(0, end.timeIntervalSince(now))
            endsAt = nil
        } else if let start = startedAt {
            accumulated += now.timeIntervalSince(start)
            startedAt = nil
        }
        stopTicker()
        isRunning = false
        refresh()
    }

    func reset() {
        stopTicker()
        isRunning = false
        endsAt = nil; startedAt = nil
        accumulated = 0
        pausedRemaining = TimeInterval(countdownFrom)
        refresh()
    }

    /// Wechselt in Countdown-Modus für eine bestimmte Übung.
    func selectCountdown(prefix: String, index: Int, name: String, seconds: Int) {
        stopTicker()
        isCountdown        = true
        countdownFrom      = seconds
        isRunning          = false
        activePrefix       = prefix
        activeIndex        = index
        activeName         = name
        endsAt = nil; startedAt = nil
        accumulated        = 0
        pausedRemaining    = TimeInterval(seconds)
        refresh()
    }

    /// Zurück in den Stopwatch-Modus, Übungsverknüpfung aufheben.
    func switchToStopwatch() {
        stopTicker()
        isCountdown        = false
        countdownFrom      = 0
        isRunning          = false
        activePrefix       = nil
        activeIndex        = nil
        activeName         = ""
        endsAt = nil; startedAt = nil
        accumulated        = 0
        pausedRemaining    = 0
        refresh()
    }

    /// View verschwindet: Ticker freigeben (sonst feuert er weiter).
    /// Ein laufender Timer läuft rechnerisch weiter.
    func detach() { stopTicker() }

    /// View erscheint wieder: Anzeige nachziehen, Ticker ggf. neu starten.
    func attach() {
        refresh()
        if isRunning { startTicker() }
    }

    // ── Intern ────────────────────────────────────────────────────────────

    private func startTicker() {
        stopTicker()
        // Kurzer Takt, damit Sekundenwechsel nicht verspätet erscheinen;
        // `.common`, damit der Timer auch beim Scrollen weiterläuft.
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        t.tolerance = 0.05
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func refresh() {
        let now = Date()
        let total: Int
        if isCountdown {
            let remaining = endsAt.map { max(0, $0.timeIntervalSince(now)) } ?? pausedRemaining
            let secs = Int(remaining.rounded(.up))
            if countdownRemaining != secs { countdownRemaining = secs }
            if isRunning && remaining <= 0 {
                // Abgelaufen
                stopTicker()
                endsAt = nil
                pausedRemaining = 0
                isRunning = false
            }
            total = secs
        } else {
            let running = startedAt.map { now.timeIntervalSince($0) } ?? 0
            total = Int(accumulated + running)
            if countdownRemaining != 0 { countdownRemaining = 0 }
        }
        let text = String(format: "%02d:%02d", total / 60, total % 60)
        if display != text { display = text }
    }
}
