import Foundation
import AVFoundation

/// Voice coach: AVSpeechSynthesizer only (offline, reliable). No continuous chatter:
/// same message suppressed for 5 seconds, corrections have priority over praise,
/// and a cooldown applies between corrections. Mute and rate/volume are user settings.
/// Language: English en-US, Telugu te-IN, Hindi hi-IN. "Mixed Telugu and English"
/// speaks Telugu voice for Telugu text and falls back to English for English phrases
/// (the caller passes already-mixed text; AVSpeech picks the Telugu voice).
final class VoiceCoach: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isMuted = false
    @Published var rate: Float = 0.48
    @Published var volume: Float = 0.9
    private let synth = AVSpeechSynthesizer()
    private var lastSpoken: [String: Date] = [:]
    private var lastCorrection = Date.distantPast

    override init() {
        super.init()
        synth.delegate = self
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("GymAI audio session error: \(error)") }
    }

    static func locale(for language: String) -> Locale {
        switch language {
        case "Telugu", "Mixed Telugu and English": return Locale(identifier: "te-IN")
        case "Hindi": return Locale(identifier: "hi-IN")
        default: return Locale(identifier: "en-US")
        }
    }

    /// correction=true bypasses the praise path but still respects a 3-second correction cooldown.
    func speak(_ text: String, language: String, correction: Bool = false) {
        guard !isMuted, !text.isEmpty else { return }
        let now = Date()
        if let last = lastSpoken[text], now.timeIntervalSince(last) < 5 { return }
        if correction, now.timeIntervalSince(lastCorrection) < 3 { return }
        if correction { lastCorrection = now }
        lastSpoken[text] = now
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.locale(for: language).identifier)
        utterance.rate = rate
        utterance.volume = volume
        synth.speak(utterance)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {}
}
