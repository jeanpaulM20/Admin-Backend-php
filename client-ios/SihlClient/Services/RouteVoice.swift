import AVFoundation
import Foundation

// MARK: - RouteVoice (Phase 5.3: Abbiegehinweise sprechen)

/// Spricht Abbiegehinweise auf Deutsch. Standardmässig aus; die Wahl wird
/// gemerkt. Während der Ansage wird andere Wiedergabe (Musik, Podcast)
/// leiser gestellt, danach läuft sie normal weiter — auch bei gesperrtem
/// Bildschirm, weil die App ohnehin Standort im Hintergrund nutzt.
@MainActor
final class RouteVoice: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = RouteVoice()

    private static let enabledKey = "routeVoiceEnabled"
    private let synthesizer = AVSpeechSynthesizer()
    private var sessionActive = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard isEnabled else { return }
        activateSession()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-CH") ?? AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateSession()
    }

    private func activateSession() {
        guard !sessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            sessionActive = true
        } catch {
            // Ohne Audio-Session spricht iOS trotzdem im Vordergrund — nur ohne Ducking
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sessionActive = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateSession() }
    }
}
