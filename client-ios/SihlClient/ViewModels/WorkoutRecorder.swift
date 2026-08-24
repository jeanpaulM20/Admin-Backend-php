import Foundation
import Observation

// MARK: - Aktivitäten (Phase 1: alle ohne GPS)

enum WorkoutActivity: String, CaseIterable, Identifiable, Codable {
    case kraft   = "Krafttraining"
    case joggen  = "Joggen"
    case rad     = "Radfahren"
    case wandern = "Wandern"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kraft:   return "dumbbell.fill"
        case .joggen:  return "figure.run"
        case .rad:     return "figure.outdoor.cycle"
        case .wandern: return "figure.hiking"
        }
    }
}

// MARK: - WorkoutRecorder

/// Aufnahme-Engine: sammelt 1-Hz-Herzfrequenz-Samples vom `HeartRateSource`,
/// führt Dauer/Statistiken und sichert alle 30 s einen Snapshot auf Platte
/// (Crash-/Kill-Recovery — ein Training darf nicht verloren gehen).
@MainActor @Observable
final class WorkoutRecorder {
    enum Phase { case setup, recording, paused, finished }

    private(set) var activity: WorkoutActivity = .kraft
    private let source: HeartRateSource

    private(set) var phase: Phase = .setup
    private(set) var hrState: HeartRateSourceState = .idle
    private(set) var currentHR: Int?
    private(set) var samples: [HrSample] = []
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0

    // Pausen-Buchhaltung: elapsed = jetzt - start - Pausensumme
    private var pausedTotal: TimeInterval = 0
    private var pauseBegan: Date?
    private var ticker: Timer?
    private var lastSnapshot = Date.distantPast

    init(source: HeartRateSource) {
        self.source = source
        source.onStateChange = { [weak self] state in self?.hrState = state }
        source.onSample = { [weak self] bpm in self?.ingest(bpm) }
    }

    // MARK: Statistiken

    var avgHR: Int? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.bpm).reduce(0, +) / samples.count
    }
    var maxHR: Int? { samples.map(\.bpm).max() }

    var durationString: String {
        let s = Int(elapsed)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// HF-Kurve für das bestehende `HrLineChart` in der Zusammenfassung.
    var hrPoints: [HrPoint] {
        let fmt = ISO8601DateFormatter()
        return samples.map { HrPoint(time: fmt.string(from: $0.t), value: Double($0.bpm)) }
    }

    // MARK: Steuerung

    func connectSensor() { source.start() }

    func startRecording(_ activity: WorkoutActivity) {
        guard phase == .setup else { return }
        self.activity = activity
        startedAt = Date()
        phase = .recording
        startTicker()
    }

    func pause() {
        guard phase == .recording else { return }
        phase = .paused
        pauseBegan = Date()
    }

    func resume() {
        guard phase == .paused, let began = pauseBegan else { return }
        pausedTotal += Date().timeIntervalSince(began)
        pauseBegan = nil
        phase = .recording
    }

    func finish() {
        guard phase == .recording || phase == .paused else { return }
        if let began = pauseBegan { pausedTotal += Date().timeIntervalSince(began); pauseBegan = nil }
        refreshElapsed()
        phase = .finished
        ticker?.invalidate()
        source.stop()
        persistSnapshot()   // bleibt bis zum erfolgreichen Upload liegen
    }

    func teardown() {
        ticker?.invalidate()
        source.stop()
    }

    // MARK: Intern

    private func ingest(_ bpm: Int) {
        currentHR = bpm
        guard phase == .recording else { return }
        samples.append(HrSample(t: Date(), bpm: bpm))
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .recording else { return }
        refreshElapsed()
        if Date().timeIntervalSince(lastSnapshot) >= 30 {
            persistSnapshot()
        }
    }

    private func refreshElapsed() {
        guard let start = startedAt else { return }
        elapsed = Date().timeIntervalSince(start) - pausedTotal
    }

    // MARK: Snapshot (Crash-Recovery)

    struct Snapshot: Codable {
        let activity: WorkoutActivity
        let startedAt: Date
        let elapsed: TimeInterval
        let samples: [HrSample]
    }

    private static var snapshotURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("active-workout.json")
    }

    private func persistSnapshot() {
        guard let start = startedAt else { return }
        lastSnapshot = Date()
        let snap = Snapshot(activity: activity, startedAt: start,
                            elapsed: elapsed, samples: samples)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: Self.snapshotURL, options: .atomic)
        }
    }

    static func clearSnapshot() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }

    /// Liegt ein unterbrochenes (nicht hochgeladenes) Training vor?
    static func pendingSnapshot() -> Snapshot? {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
              snap.samples.count >= 10 else { return nil }
        return snap
    }
}
