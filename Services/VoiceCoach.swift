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
    private var beepPlayer: AVAudioPlayer?
    private var lastBeep = Date.distantPast

    /// Loud beep when the position is wrong. Deliberately NOT gated by
    /// isMuted: mute silences the spoken coach, but the user asked for a
    /// loud wrong-position alert, so a beep must still be heard. Throttled
    /// to at most one beep every 2 seconds so it does not become a siren.
    /// The tone is generated in code (880 Hz sine, 0.35 s, full volume) —
    /// no audio file is needed.
    func playWrongBeep() {
        let now = Date()
        guard now.timeIntervalSince(lastBeep) >= 2 else { return }
        lastBeep = now
        let sampleRate = 44100, duration = 0.35, freq = 880.0
        let count = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: count * 2)
        for i in 0..<count {
            let s = sin(2 * .pi * freq * Double(i) / Double(sampleRate))
            var v = Int16(s * 28000)
            pcm.append(Data(bytes: &v, count: 2))
        }
        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 2)) }
        wav.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + pcm.count)); wav.append("WAVE".data(using: .ascii)!)
        wav.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        wav.append("data".data(using: .ascii)!); u32(UInt32(pcm.count)); wav.append(pcm)
        guard let player = try? AVAudioPlayer(data: wav) else { return }
        beepPlayer = player
        player.volume = 1.0
        player.play()
    }

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

    // MARK: - Human-like Telugu voice
    // Honest note: no automated voice is a real human recording. The bundled
    // clips (Resources/TeluguVoice/*.mp3, generated with te-IN-ShrutiNeural,
    // see scripts/generate_telugu_voice.py) are a neural voice trained on
    // human speech — far more natural than AVSpeech — and they play offline.
    // If a clip is missing, this falls back to AVSpeech te-IN.
    private var teluguPlayer: AVAudioPlayer?

    /// Map an English correction to a bundled Telugu clip key, or nil.
    static func teluguClipKey(for text: String) -> String? {
        let t = text.lowercased()
        if t.contains("good repetition") { return "good_rep" }
        if t.contains("elbows closer") || t.contains("elbows close") { return "elbows_close" }
        if t.contains("both sides even") { return "sides_even" }
        if t.contains("shoulder height") { return "shoulder_height" }
        if t.contains("hips level") || t.contains("sag or pike") { return "hips_level" }
        if t.contains("lower slowly") || t.contains("lower under control") || t.contains("lowering") { return "lower_slowly" }
        if t.contains("chest stable") { return "chest_stable" }
        if t.contains("control your descent") || t.contains("control the movement") { return "control_descent" }
        if t.contains("press smoothly") || t.contains("press") { return "press_smoothly" }
        if t.contains("good depth") { return "good_depth" }
        if t.contains("back flat") { return "keep_back_flat" }
        if t.contains("unable to assess") { return "unable_assess" }
        if t.contains("pain") { return "pain_stop" }
        return nil
    }

    /// Speak a correction in the user's trainer language. For Telugu / Mixed,
    /// prefer the bundled human-like Telugu clip; otherwise use AVSpeech.
    func speakCorrection(_ text: String, language: String) {
        if language == "Telugu" || language == "Mixed Telugu and English",
           let key = Self.teluguClipKey(for: text),
           let url = Bundle.main.url(forResource: key, withExtension: "mp3", subdirectory: "TeluguVoice"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            // Respect the same mute + repeat suppression as speak().
            guard !isMuted else { return }
            let now = Date()
            if let last = lastSpoken[text], now.timeIntervalSince(last) < 5 { return }
            lastSpoken[text] = now
            teluguPlayer = player
            player.volume = volume
            player.play()
            return
        }
        speak(text, language: language, correction: true)
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
