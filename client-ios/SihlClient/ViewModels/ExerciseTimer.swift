import Foundation

/// Trainings-Timer — Stopwatch- und Countdown-Modus.
/// Pendant zu `providers/exercise_timer.dart`.
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
    private var ticker: Timer?
    private var elapsed = 0   // Sekunden (Stopwatch-Modus)

    // ── Steuerung ─────────────────────────────────────────────────────────

    func toggle() { isRunning ? pause() : start() }

    func start() {
        if isCountdown && countdownRemaining <= 0 { reset(); return }
        isRunning = true
        if isCountdown {
            ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.countdownRemaining -= 1
                    if self.countdownRemaining <= 0 {
                        self.countdownRemaining = 0
                        self.isRunning = false
                        self.ticker?.invalidate()
                        self.ticker = nil
                    }
                    self.refreshDisplay()
                }
            }
        } else {
            ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.elapsed += 1
                    self.refreshDisplay()
                }
            }
        }
        refreshDisplay()
    }

    func pause() {
        ticker?.invalidate(); ticker = nil
        isRunning = false
    }

    func reset() {
        ticker?.invalidate(); ticker = nil
        isRunning = false
        if isCountdown { countdownRemaining = countdownFrom } else { elapsed = 0 }
        refreshDisplay()
    }

    /// Wechselt in Countdown-Modus für eine bestimmte Übung.
    func selectCountdown(prefix: String, index: Int, name: String, seconds: Int) {
        ticker?.invalidate(); ticker = nil
        isCountdown        = true
        countdownFrom      = seconds
        countdownRemaining = seconds
        isRunning          = false
        activePrefix       = prefix
        activeIndex        = index
        activeName         = name
        elapsed            = 0
        refreshDisplay()
    }

    /// Zurück in den Stopwatch-Modus, Übungsverknüpfung aufheben.
    func switchToStopwatch() {
        ticker?.invalidate(); ticker = nil
        isCountdown        = false
        countdownFrom      = 0
        countdownRemaining = 0
        isRunning          = false
        activePrefix       = nil
        activeIndex        = nil
        activeName         = ""
        elapsed            = 0
        refreshDisplay()
    }

    // ── Intern ────────────────────────────────────────────────────────────

    private func refreshDisplay() {
        let total = isCountdown ? countdownRemaining : elapsed
        display = String(format: "%02d:%02d", total / 60, total % 60)
    }
}
