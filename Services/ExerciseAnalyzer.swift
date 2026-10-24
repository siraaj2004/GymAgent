import Foundation

/// Exercise-specific rep counting. Each exercise has its OWN thresholds and state
/// machine — deliberately not one generic angle threshold.
/// A rep counts only on a full bottom -> top (or top -> bottom -> top) transition
/// with sufficient confidence; otherwise the frame is ignored, never guessed.
enum ExerciseKind {
    case squat, pushUp, lunge, bicepCurl, shoulderPress, lateralRaise, romanianDeadlift, pullUp, dumbbellRow, plank, legRaise, manual, neckInstructional

    /// Maps a plan exercise name to the closest supported tracker. Anything else
    /// (machines, cables, most isolation work) is .manual: the user taps to count,
    /// and the app never pretends the camera tracked it.
    static func forExercise(_ name: String) -> ExerciseKind {
        let n = name.lowercased()
        if n.contains("neck") { return .neckInstructional }
        if n.contains("plank") || n.contains("dead bug") { return .plank }
        if n.contains("squat") { return .squat }
        if n.contains("push-up") || n.contains("push-ups") || n.contains("push-up plus") { return .pushUp }
        if n.contains("lunge") || n.contains("split squat") { return .lunge }
        if n.contains("curl") { return .bicepCurl }
        if n.contains("shoulder press") || n.contains("landmine press") { return .shoulderPress }
        if n.contains("lateral raise") { return .lateralRaise }
        if n.contains("deadlift") || n.contains("good morning") { return .romanianDeadlift }
        if n.contains("pull-up") || n.contains("pulldown") { return .pullUp }
        if n.contains("row") { return .dumbbellRow }
        if n.contains("leg raise") || n.contains("crunch") { return .legRaise }
        return .manual
    }
}

struct AnalysisResult {
    var reps: Int
    var feedback: String
    var isCorrection: Bool
    var assessable: Bool
    var holdSeconds: Double
}

final class ExerciseAnalyzer {
    let kind: ExerciseKind
    private(set) var reps = 0
    private var phase: String = "top" // top / bottom / hold
    private var holdStart: Date?
    private(set) var holdSeconds: Double = 0
    private var lastFeedback = ""

    init(kind: ExerciseKind) { self.kind = kind }

    static func angle(a: PosePoint, b: PosePoint, c: PosePoint) -> Double {
        // Angle at b between a-b and c-b, in degrees.
        let v1x = a.x - b.x, v1y = a.y - b.y, v2x = c.x - b.x, v2y = c.y - b.y
        let dot = v1x * v2x + v1y * v2y
        let m1 = max(0.0001, (v1x * v1x + v1y * v1y).squareRoot())
        let m2 = max(0.0001, (v2x * v2x + v2y * v2y).squareRoot())
        let cosA = min(1, max(-1, dot / (m1 * m2)))
        return acos(cosA) * 180 / Double.pi
    }

    /// Feed one frame. Returns feedback only when it changes or a rep completes.
    func update(frame: PoseFrame) -> AnalysisResult {
        guard kind != .manual else {
            return AnalysisResult(reps: reps, feedback: "Camera tracking is not reliable for this movement. Tap to count reps manually.", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        guard kind != .neckInstructional else {
            return AnalysisResult(reps: reps, feedback: "Neck work: very light, slow and controlled. No aggressive correction. Stop for pain, dizziness or numbness.", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        guard frame.assessable else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess — move so the required joints are visible.", isCorrection: false, assessable: false, holdSeconds: holdSeconds)
        }
        switch kind {
        case .squat: return trackSquat(frame)
        case .bicepCurl: return trackCurl(frame)
        case .pushUp: return trackPushUp(frame)
        case .plank: return trackPlank(frame)
        case .shoulderPress: return trackPress(frame)
        case .lateralRaise: return trackRaise(frame)
        case .romanianDeadlift: return trackHinge(frame)
        case .pullUp: return trackPullUp(frame)
        case .lunge: return trackLunge(frame)
        case .dumbbellRow: return trackRow(frame)
        case .legRaise: return trackLegRaise(frame)
        default: return AnalysisResult(reps: reps, feedback: "Tracking…", isCorrection: false, assessable: true, holdSeconds: 0)
        }
    }

    private func emit(_ text: String, correction: Bool, counted: Bool = false) -> AnalysisResult {
        if counted { reps += 1 }
        lastFeedback = text
        return AnalysisResult(reps: reps, feedback: text, isCorrection: correction, assessable: true, holdSeconds: holdSeconds)
    }

    private func kneeAngle(_ f: PoseFrame) -> Double? {
        guard let h = f.point("lHip"), let k = f.point("lKnee"), let a = f.point("lAnkle") else { return nil }
        return Self.angle(a: h, b: k, c: a)
    }
    private func elbowAngle(_ f: PoseFrame, left: Bool = true) -> Double? {
        guard let s = f.point(left ? "lShoulder" : "rShoulder"), let e = f.point(left ? "lElbow" : "rElbow"), let w = f.point(left ? "lWrist" : "rWrist") else { return nil }
        return Self.angle(a: s, b: e, c: w)
    }

    private func trackSquat(_ f: PoseFrame) -> AnalysisResult {
        guard let knee = kneeAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "top", knee < 100 { phase = "bottom"; return emit("Good depth. Now stand up smoothly.", correction: false) }
        if phase == "bottom", knee > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        if phase == "bottom", knee < 70 { return emit("Control your descent.", correction: true) }
        return AnalysisResult(reps: reps, feedback: "Keep your chest stable.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackCurl(_ f: PoseFrame) -> AnalysisResult {
        guard let elbow = elbowAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        // Track extension (top) -> flexion (bottom) -> extension = 1 rep. Phase names reused.
        if phase == "top", elbow < 60 { phase = "bottom"; return emit("Good curl.", correction: false) }
        if phase == "bottom", elbow > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        if let s = f.point("lShoulder"), let e = f.point("lElbow"), abs(e.x - s.x) > 0.18 {
            return emit("Keep your elbows closer to your body.", correction: true)
        }
        return AnalysisResult(reps: reps, feedback: "Control the movement while lowering the dumbbell.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackPushUp(_ f: PoseFrame) -> AnalysisResult {
        guard let elbow = elbowAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "top", elbow < 90 { phase = "bottom"; return emit("Good depth.", correction: false) }
        if phase == "bottom", elbow > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Keep your body in a straight line.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackPlank(_ f: PoseFrame) -> AnalysisResult {
        // Timed hold: shoulder-hip-ankle roughly in line. No rep count; hold time accumulates.
        guard let s = f.point("lShoulder"), let h = f.point("lHip"), let a = f.point("lAnkle") else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: holdSeconds)
        }
        let line = Self.angle(a: s, b: h, c: a)
        if line > 150 {
            if holdStart == nil { holdStart = Date() }
            holdSeconds = Date().timeIntervalSince(holdStart ?? Date())
            return AnalysisResult(reps: reps, feedback: "Hold steady — \(Int(holdSeconds)) seconds.", isCorrection: false, assessable: true, holdSeconds: holdSeconds)
        }
        holdStart = nil
        return emit("Keep your hips level — do not sag or pike.", correction: true)
    }

    private func trackPress(_ f: PoseFrame) -> AnalysisResult {
        guard let elbow = elbowAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "bottom", elbow > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        if phase == "top", elbow < 90 { phase = "bottom"; return emit("Control the lowering.", correction: false) }
        return AnalysisResult(reps: reps, feedback: "Press smoothly overhead.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackRaise(_ f: PoseFrame) -> AnalysisResult {
        guard let s = f.point("lShoulder"), let e = f.point("lElbow"), let w = f.point("lWrist") else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        let height = w.y - s.y // Vision y increases upward; raised arm is above shoulder
        _ = e
        if phase == "top", height > 0.15 { phase = "bottom"; return emit("Good height. Lower slowly.", correction: false) }
        if phase == "bottom", height < 0.02 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Raise to shoulder height, not above.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackHinge(_ f: PoseFrame) -> AnalysisResult {
        guard let s = f.point("lShoulder"), let h = f.point("lHip"), let k = f.point("lKnee") else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        let hip = Self.angle(a: s, b: h, c: k)
        if phase == "top", hip < 100 { phase = "bottom"; return emit("Good hinge. Drive your hips forward.", correction: false) }
        if phase == "bottom", hip > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Keep your back flat and the movement slow.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackPullUp(_ f: PoseFrame) -> AnalysisResult {
        guard let elbow = elbowAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "bottom", elbow < 70 { phase = "top"; return emit("Good pull.", correction: false) }
        if phase == "top", elbow > 160 { phase = "bottom"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Lower under control — do not drop.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackLunge(_ f: PoseFrame) -> AnalysisResult {
        guard let knee = kneeAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "top", knee < 110 { phase = "bottom"; return emit("Good depth. Drive up.", correction: false) }
        if phase == "bottom", knee > 160 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Keep your chest up and your front knee tracking forward.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackRow(_ f: PoseFrame) -> AnalysisResult {
        guard let elbow = elbowAngle(f) else { return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0) }
        if phase == "top", elbow < 70 { phase = "bottom"; return emit("Good row. Squeeze at the top.", correction: false) }
        if phase == "bottom", elbow > 150 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Pull your elbow back, keep your torso still.", isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func trackLegRaise(_ f: PoseFrame) -> AnalysisResult {
        guard let s = f.point("lShoulder"), let h = f.point("lHip"), let a = f.point("lAnkle") else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        let hip = Self.angle(a: s, b: h, c: a)
        if phase == "top", hip < 100 { phase = "bottom"; return emit("Good raise. Lower slowly.", correction: false) }
        if phase == "bottom", hip > 150 { phase = "top"; return emit("Good repetition!", correction: false, counted: true) }
        return AnalysisResult(reps: reps, feedback: "Raise with control, do not swing.", isCorrection: false, assessable: true, holdSeconds: 0)
    }
}
