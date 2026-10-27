import Foundation

/// Coverage for ALL 71 exercises in the user's 5-day plan.
///
/// How it works, honestly:
/// - The camera only sees body joints (shoulders, elbows, wrists, hips, knees, ankles).
///   It cannot see weight, grip, machine stack, or muscle effort.
/// - So every exercise is mapped to the joint movement the camera CAN see:
///   elbow bending, knee bending, hip bending, arm raising, arm/leg distance,
///   heel/wrist lifting, or a held body line.
/// - A rep counts only on a full out-and-back movement (for example: straight ->
///   bent -> straight again). A half movement never counts, and a low-confidence
///   frame never counts.
/// - `checks` is what the camera checks. `cannotCheck` is what it cannot check —
///   shown in the app for every exercise, so no one is misled.
/// - Neck exercises are the one exception: instructional guidance only, never
///   aggressive correction, because neck work must stay very light and controlled.
enum MovementPattern {
    case jointAngle // elbow, knee or hip angle, chosen by `joint`
    case armHeight // wrist height above shoulder (raises)
    case wristDistance // distance between the two wrists (flys)
    case ankleDistance // distance between the two ankles (adductor/abductor)
    case verticalLift // heel, toe or wrist lifting from its starting height
    case bodyLineHold // plank / side plank / dead-bug-style hold
    case neckInstructional
}

struct ExerciseGuide {
    var pattern: MovementPattern
    var joint: String // "elbow", "knee", "hip" for jointAngle; otherwise ignored
    var low: Double // flexed / down / narrow value
    var high: Double // extended / up / wide value
    var liftDelta: Double // for verticalLift only
    var checks: String
    var cannotCheck: String
    var correction: String
    var camera: String
}

enum AllExerciseGuide {
    static func guide(for name: String) -> ExerciseGuide? {
        let n = name.lowercased()
        // Neck first: safety rule, always instructional.
        if n.contains("neck") {
            return ExerciseGuide(pattern: .neckInstructional, joint: "", low: 0, high: 0, liftDelta: 0,
                                 checks: "Only gentle timing and stillness guidance.",
                                 cannotCheck: "Neck force, pain, or exact neck angle — never guessed.",
                                 correction: "Very light and slow. Stop for pain, dizziness or numbness.",
                                 camera: "Face the camera, head and shoulders visible, move very slowly.")
        }
        // Holds.
        if n.contains("plank") || n.contains("dead bug") || n.contains("body saw") {
            return ExerciseGuide(pattern: .bodyLineHold, joint: "", low: 0, high: 0, liftDelta: 0,
                                 checks: "Shoulder-hip-ankle line stays straight, and hold time.",
                                 cannotCheck: "How hard your core is working, or low-back contact with the floor.",
                                 correction: "Keep your hips level — do not sag or pike.",
                                 camera: "Phone to your side, head to feet in frame.")
        }
        // Vertical lifts: calves, tibialis, wrists.
        if n.contains("calf raise") {
            return ExerciseGuide(pattern: .verticalLift, joint: "ankle", low: 0, high: 0, liftDelta: 0.03,
                                 checks: "Heel lifting rhythm and knees staying straight.",
                                 cannotCheck: "Exact heel height or calf effort.",
                                 correction: "Lift fully, pause at the top, lower slowly.",
                                 camera: "Phone to your side, feet and ankles in frame.")
        }
        if n.contains("tibialis") {
            return ExerciseGuide(pattern: .verticalLift, joint: "ankle", low: 0, high: 0, liftDelta: 0.02,
                                 checks: "Toe-lifting rhythm and knees staying still.",
                                 cannotCheck: "Exact toe height — the toes are too small for body-pose tracking.",
                                 correction: "Lift your toes fully, lower slowly, keep your knees still.",
                                 camera: "Phone to your side, feet in frame.")
        }
        if n.contains("wrist curl") {
            return ExerciseGuide(pattern: .verticalLift, joint: "wrist", low: 0, high: 0, liftDelta: 0.02,
                                 checks: "Wrist lifting rhythm and forearm staying still.",
                                 cannotCheck: "Exact wrist angle or grip strength.",
                                 correction: "Move only your wrist, keep your forearm still.",
                                 camera: "Phone in front, forearms and wrists in frame.")
        }
        if n.contains("pronation") || n.contains("supination") {
            return ExerciseGuide(pattern: .verticalLift, joint: "wrist", low: 0, high: 0, liftDelta: 0.02,
                                 checks: "Slow, controlled wrist movement and steady rhythm.",
                                 cannotCheck: "Exact rotation degrees — body pose has no finger/hand rotation.",
                                 correction: "Turn slowly and fully, do not rush or swing your arm.",
                                 camera: "Phone in front, forearms and wrists in frame.")
        }
        // Arm raises: wrist height above shoulder.
        if n.contains("lateral raise") || n.contains("rear-delt fly") || n.contains("reverse pec deck") {
            return ExerciseGuide(pattern: .armHeight, joint: "", low: 0.02, high: 0.15, liftDelta: 0,
                                 checks: "Arm raising to shoulder height and slow lowering.",
                                 cannotCheck: "Weight, or which deltoid head is working hardest.",
                                 correction: "Raise to shoulder height, not above. Lower slowly.",
                                 camera: "Phone in front, shoulders, elbows and wrists visible.")
        }
        // Flys: wrists move together and apart.
        if n.contains("fly") {
            return ExerciseGuide(pattern: .wristDistance, joint: "", low: 0.15, high: 0.40, liftDelta: 0,
                                 checks: "Arms opening wide and closing together, elbows slightly bent.",
                                 cannotCheck: "Cable weight or chest stretch force.",
                                 correction: "Open wide, squeeze together slowly, keep elbows slightly bent.",
                                 camera: "Phone in front, both arms fully visible.")
        }
        // Hip adduction / abduction: ankles move apart and together.
        if n.contains("adduct") || n.contains("abduct") {
            return ExerciseGuide(pattern: .ankleDistance, joint: "", low: 0.15, high: 0.30, liftDelta: 0,
                                 checks: "Legs opening and closing, torso staying still.",
                                 cannotCheck: "Machine weight or exact hip angle.",
                                 correction: "Move slowly, keep your torso still, do not swing.",
                                 camera: "Phone in front, hips to feet in frame.")
        }
        if n.contains("shrug") {
            return ExerciseGuide(pattern: .verticalLift, joint: "shoulder", low: 0, high: 0, liftDelta: 0.03,
                                 checks: "Shoulder lifting rhythm.",
                                 cannotCheck: "Trap effort or weight.",
                                 correction: "Lift your shoulders straight up, pause, lower slowly. Do not roll.",
                                 camera: "Phone in front, shoulders visible.")
        }
        // Elbow movements, each with its OWN correction text — not one shared
        // message for every elbow exercise. Before this, curls, rows and
        // pulldowns all spoke the same "Pull smoothly" line.
        if n.contains("press") || n.contains("push-up") || n.contains("push-ups") || n.contains("bench") || n.contains("extension") || n.contains("pushdown") || n.contains("punch") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 90, high: 160, liftDelta: 0,
                                 checks: "Elbow bending and straightening, and both arms staying even.",
                                 cannotCheck: "Weight, bar path, or back arch.",
                                 correction: "Press smoothly. Keep both arms even and lower under control.",
                                 camera: "Phone in front, shoulders, elbows and wrists visible.")
        }
        // Curls get a lower "low" (50, not 70): from the front camera, a full
        // curl's 2D elbow angle looks larger than the true angle, so 70 made
        // real full curls look like half reps and triggered constant corrections.
        if n.contains("curl") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 50, high: 160, liftDelta: 0,
                                 checks: "Elbow curling fully and lowering, both sides even.",
                                 cannotCheck: "Weight, grip, or bicep effort.",
                                 correction: "Curl smoothly, keep your elbows still at your sides, lower under control.",
                                 camera: "Phone in front, upper body and arms fully visible.")
        }
        if n.contains("face pull") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 70, high: 160, liftDelta: 0,
                                 checks: "Elbow bending and straightening, and both sides staying even.",
                                 cannotCheck: "Weight, grip, or back engagement.",
                                 correction: "Pull to your forehead, keep your elbows high, lower slowly.",
                                 camera: "Phone in front, upper body and arms fully visible.")
        }
        if n.contains("pull-up") || n.contains("pulldown") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 70, high: 160, liftDelta: 0,
                                 checks: "Elbow bending and straightening, and both sides staying even.",
                                 cannotCheck: "Weight, grip, or back engagement.",
                                 correction: "Pull smoothly, keep your chest up, lower under control.",
                                 camera: "Phone in front, upper body and arms fully visible.")
        }
        if n.contains("row") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 70, high: 160, liftDelta: 0,
                                 checks: "Elbow bending and straightening, and both sides staying even.",
                                 cannotCheck: "Weight, grip, or back engagement.",
                                 correction: "Row smoothly, keep your back flat, squeeze at the top.",
                                 camera: "Phone in front, upper body and arms fully visible.")
        }
        if n.contains("external rotation") || n.contains("rotation") {
            return ExerciseGuide(pattern: .jointAngle, joint: "elbow", low: 70, high: 160, liftDelta: 0,
                                 checks: "Elbow bending and straightening, and both sides staying even.",
                                 cannotCheck: "Weight, grip, or back engagement.",
                                 correction: "Rotate slowly, keep your elbow tucked, do not swing.",
                                 camera: "Phone in front, upper body and arms fully visible.")
        }
        // Knee movements, each with its own correction.
        if n.contains("lunge") || n.contains("split squat") {
            return ExerciseGuide(pattern: .jointAngle, joint: "knee", low: 100, high: 160, liftDelta: 0,
                                 checks: "Knee bending and standing back up, both legs even.",
                                 cannotCheck: "Weight, foot pressure, or knee tracking in 3D.",
                                 correction: "Step steady, keep your front knee tracking forward, stand up smoothly.",
                                 camera: "Phone to your side, full body in frame, knees and hips visible.")
        }
        if n.contains("leg extension") {
            return ExerciseGuide(pattern: .jointAngle, joint: "knee", low: 100, high: 160, liftDelta: 0,
                                 checks: "Knee extending fully and lowering, both legs even.",
                                 cannotCheck: "Weight, foot pressure, or knee tracking in 3D.",
                                 correction: "Extend fully, lower slowly, keep your knees still.",
                                 camera: "Phone to your side, full body in frame, knees and hips visible.")
        }
        if n.contains("leg curl") {
            return ExerciseGuide(pattern: .jointAngle, joint: "knee", low: 100, high: 160, liftDelta: 0,
                                 checks: "Knee curling and lowering, both legs even.",
                                 cannotCheck: "Weight, foot pressure, or knee tracking in 3D.",
                                 correction: "Curl slowly, keep your hips down, lower under control.",
                                 camera: "Phone to your side, full body in frame, knees and hips visible.")
        }
        if n.contains("squat") || n.contains("leg press") {
            return ExerciseGuide(pattern: .jointAngle, joint: "knee", low: 100, high: 160, liftDelta: 0,
                                 checks: "Knee bending to depth and standing back up, both legs even.",
                                 cannotCheck: "Weight, foot pressure, or knee tracking in 3D.",
                                 correction: "Keep your chest up, bend to good depth, stand up smoothly.",
                                 camera: "Phone to your side, full body in frame, knees and hips visible.")
        }
        // Hip movements, each with its own correction.
        if n.contains("deadlift") || n.contains("good morning") {
            return ExerciseGuide(pattern: .jointAngle, joint: "hip", low: 100, high: 160, liftDelta: 0,
                                 checks: "Hip bending and extending, and torso staying controlled.",
                                 cannotCheck: "Weight, low-back load, or core bracing.",
                                 correction: "Hinge slowly, keep your back flat, drive your hips forward.",
                                 camera: "Phone to your side, hips and torso fully visible.")
        }
        if n.contains("hip thrust") || n.contains("glute bridge") {
            return ExerciseGuide(pattern: .jointAngle, joint: "hip", low: 100, high: 160, liftDelta: 0,
                                 checks: "Hip extending fully and lowering, torso controlled.",
                                 cannotCheck: "Weight, low-back load, or core bracing.",
                                 correction: "Thrust fully, squeeze at the top, lower slowly.",
                                 camera: "Phone to your side, hips and torso fully visible.")
        }
        if n.contains("crunch") {
            return ExerciseGuide(pattern: .jointAngle, joint: "hip", low: 100, high: 160, liftDelta: 0,
                                 checks: "Torso crunching and lowering, controlled.",
                                 cannotCheck: "Weight, low-back load, or core bracing.",
                                 correction: "Crunch slowly, keep your neck relaxed, lower under control.",
                                 camera: "Phone to your side, hips and torso fully visible.")
        }
        if n.contains("leg raise") {
            return ExerciseGuide(pattern: .jointAngle, joint: "hip", low: 100, high: 160, liftDelta: 0,
                                 checks: "Legs raising and lowering, torso controlled.",
                                 cannotCheck: "Weight, low-back load, or core bracing.",
                                 correction: "Raise slowly, keep your low back still, lower under control.",
                                 camera: "Phone to your side, hips and torso fully visible.")
        }
        if n.contains("back extension") || n.contains("reverse hyper") || n.contains("pallof") {
            return ExerciseGuide(pattern: .jointAngle, joint: "hip", low: 100, high: 160, liftDelta: 0,
                                 checks: "Hip bending and extending, and torso staying controlled.",
                                 cannotCheck: "Weight, low-back load, or core bracing.",
                                 correction: "Move slowly, keep your back flat, drive your hips forward.",
                                 camera: "Phone to your side, hips and torso fully visible.")
        }
        return nil
    }
}

/// Universal analyser: one out-and-back oscillation per exercise, using the guide above.
/// It reuses AnalysisResult from ExerciseAnalyzer.swift so the UI and voice code do not change.
final class UniversalExerciseAnalyzer {
    let exerciseName: String
    let guide: ExerciseGuide?
    private(set) var reps = 0
    private var phase: String = "unknown" // "low", "high", or "unknown"
    private var firstExtreme: String?
    private var attemptedPartial = false
    private var baseValue: Double?
    private(set) var holdSeconds: Double = 0
    private var holdStart: Date?
    // "Unable to assess" debounce: a single dropped frame (dumbbell briefly
    // covering a wrist, a person walking behind you, a bench edge) must not
    // flip the screen and voice to a correction every time. Only the 3rd
    // consecutive unassessable frame is a spoken correction; earlier ones
    // still report assessable=false so the UI can hold its last good state,
    // but with isCorrection=false so the voice stays quiet.
    private var unassessableStreak = 0

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        self.guide = AllExerciseGuide.guide(for: exerciseName)
    }

    private static func angle(a: PosePoint, b: PosePoint, c: PosePoint) -> Double {
        ExerciseAnalyzer.angle(a: a, b: b, c: c)
    }

    private func jointAngle(_ f: PoseFrame, joint: String) -> Double? {
        switch joint {
        case "elbow":
            guard let s = f.point("lShoulder"), let e = f.point("lElbow"), let w = f.point("lWrist") else { return nil }
            return Self.angle(a: s, b: e, c: w)
        case "knee":
            guard let h = f.point("lHip"), let k = f.point("lKnee"), let a = f.point("lAnkle") else { return nil }
            return Self.angle(a: h, b: k, c: a)
        case "hip":
            guard let s = f.point("lShoulder"), let h = f.point("lHip"), let k = f.point("lKnee") else { return nil }
            return Self.angle(a: s, b: h, c: k)
        default: return nil
        }
    }

    private func value(for f: PoseFrame, guide: ExerciseGuide) -> Double? {
        switch guide.pattern {
        case .jointAngle: return jointAngle(f, joint: guide.joint)
        case .armHeight:
            guard let s = f.point("lShoulder"), let w = f.point("lWrist") else { return nil }
            return w.y - s.y
        case .wristDistance:
            guard let l = f.point("lWrist"), let r = f.point("rWrist") else { return nil }
            return abs(l.x - r.x)
        case .ankleDistance:
            guard let l = f.point("lAnkle"), let r = f.point("rAnkle") else { return nil }
            return abs(l.x - r.x)
        case .verticalLift:
            let key = guide.joint == "shoulder" ? "lShoulder" : guide.joint == "wrist" ? "lWrist" : "lAnkle"
            guard let p = f.point(key) else { return nil }
            if baseValue == nil { baseValue = p.y }
            return p.y - (baseValue ?? p.y)
        case .bodyLineHold, .neckInstructional: return nil
        }
    }

    func update(frame: PoseFrame) -> AnalysisResult {
        guard let guide else {
            return AnalysisResult(reps: reps, feedback: "Tap to count reps by hand for this exercise.", isCorrection: false, assessable: false, holdSeconds: 0)
        }
        if guide.pattern == .neckInstructional {
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: false, assessable: false, holdSeconds: 0)
        }
        guard frame.assessable else {
            // Wrong phone position / joints not visible IS a voice correction,
            // but only after it persists — see unassessableStreak above.
            // The user cannot fix a position they are not told about, but a
            // one-frame dropout is not a position error.
            unassessableStreak += 1
            let spoken = unassessableStreak >= 3
            return AnalysisResult(reps: reps, feedback: "Unable to assess — move so the required joints are visible.", isCorrection: spoken, assessable: false, holdSeconds: holdSeconds)
        }
        unassessableStreak = 0
        if guide.pattern == .bodyLineHold {
            guard let s = f_point(frame, "lShoulder"), let h = f_point(frame, "lHip"), let a = f_point(frame, "lAnkle") else {
                return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: false, assessable: false, holdSeconds: holdSeconds)
            }
            let line = Self.angle(a: s, b: h, c: a)
            if line > 150 {
                if holdStart == nil { holdStart = Date() }
                holdSeconds = Date().timeIntervalSince(holdStart ?? Date())
                return AnalysisResult(reps: reps, feedback: "Hold steady — \(Int(holdSeconds)) seconds.", isCorrection: false, assessable: true, holdSeconds: holdSeconds)
            }
            holdStart = nil
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: holdSeconds)
        }
        guard let v = value(for: frame, guide: guide) else {
            return AnalysisResult(reps: reps, feedback: "Unable to assess", isCorrection: true, assessable: false, holdSeconds: 0)
        }
        let low = guide.pattern == .verticalLift ? 0.005 : guide.low
        let high = guide.pattern == .verticalLift ? guide.liftDelta : guide.high
        // Voice correction for a clearly wrong position (overshoot), for every
        // exercise family where it is measurable: arm raised too high, or a
        // joint bent far past the rep range. This is spoken by the caller.
        if guide.pattern == .armHeight, v > high + 0.10 {
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0)
        }
        if guide.pattern == .jointAngle, v < low - 30 {
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0)
        }
        // Same overshoot idea for distance movements: arms / legs opened far
        // wider than the rep range is a wrong position, not a better rep.
        if guide.pattern == .wristDistance, v > high + 0.10 {
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0)
        }
        if guide.pattern == .ankleDistance, v > high + 0.10 {
            return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0)
        }
        // Track a partial (half) rep attempt: moved from the starting extreme
        // into the middle, then back to the same extreme without ever reaching
        // the opposite extreme. That is a wrong / incomplete rep, not a counted
        // rep — speak the exercise's correction for it.
        if guide.pattern != .verticalLift, high > low, let first = firstExtreme {
            let midLow = low + (high - low) * 0.25, midHigh = high - (high - low) * 0.25
            if phase == first, v > midLow, v < midHigh { attemptedPartial = true }
        }
        // Generic out-and-back: first extreme -> opposite extreme -> back to first = 1 rep.
        if v <= low {
            if firstExtreme == nil { firstExtreme = "low"; phase = "low" }
            else if phase == "high", firstExtreme == "low" { attemptedPartial = false; reps += 1; phase = "low"; return AnalysisResult(reps: reps, feedback: "Good repetition!", isCorrection: false, assessable: true, holdSeconds: 0) }
            else if attemptedPartial, firstExtreme == "low", phase == "low" { attemptedPartial = false; return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0) }
            else { phase = "low" }
        } else if v >= high {
            if firstExtreme == nil { firstExtreme = "high"; phase = "high" }
            else if phase == "low", firstExtreme == "high" { attemptedPartial = false; reps += 1; phase = "high"; return AnalysisResult(reps: reps, feedback: "Good repetition!", isCorrection: false, assessable: true, holdSeconds: 0) }
            else if attemptedPartial, firstExtreme == "high", phase == "high" { attemptedPartial = false; return AnalysisResult(reps: reps, feedback: guide.correction, isCorrection: true, assessable: true, holdSeconds: 0) }
            else { phase = "high" }
        }
        // Asymmetry check for elbow/knee/hip: left vs right angle differing a lot.
        // Confidence gate (the bug in the gym video): the old code used the
        // right-side points even when Vision was barely confident about them
        // (dumbbell covering a wrist, an arm crossing the body, another person
        // behind you), so a noisy right angle triggered "Keep both sides
        // even" on almost every frame even when both sides were even.
        // Now both right joints must be at least 0.3 confident, or no
        // asymmetry correction is given at all.
        if guide.joint == "elbow" || guide.joint == "knee" || guide.joint == "hip" {
            let rightConfident: Bool = {
                let keys: [String]
                if guide.joint == "elbow" { keys = ["rShoulder", "rElbow", "rWrist"] }
                else if guide.joint == "hip" { keys = ["rShoulder", "rHip", "rKnee"] }
                else { keys = ["rHip", "rKnee", "rAnkle"] }
                return keys.allSatisfy { (frame.point($0)?.confidence ?? 0) >= 0.3 }
            }()
            if rightConfident {
                let left = jointAngle(frame, joint: guide.joint)
                let right: Double? = {
                    if guide.joint == "elbow" {
                        guard let s = frame.point("rShoulder"), let e = frame.point("rElbow"), let w = frame.point("rWrist") else { return nil }
                        return Self.angle(a: s, b: e, c: w)
                    } else if guide.joint == "hip" {
                        guard let s = frame.point("rShoulder"), let h = frame.point("rHip"), let k = frame.point("rKnee") else { return nil }
                        return Self.angle(a: s, b: h, c: k)
                    } else {
                        guard let h = frame.point("rHip"), let k = frame.point("rKnee"), let a = frame.point("rAnkle") else { return nil }
                        return Self.angle(a: h, b: k, c: a)
                    }
                }()
                if let l = left, let r = right, abs(l - r) > 25 {
                    return AnalysisResult(reps: reps, feedback: "Keep both sides even.", isCorrection: true, assessable: true, holdSeconds: 0)
                }
            }
        }
        // Asymmetry for raises: one arm much higher than the other, with the
        // same confidence gate on the right side.
        if guide.pattern == .armHeight {
            if let rs = frame.point("rShoulder"), let rw = frame.point("rWrist"),
               rs.confidence >= 0.3, rw.confidence >= 0.3,
               abs(v - (rw.y - rs.y)) > 0.10 {
                return AnalysisResult(reps: reps, feedback: "Keep both sides even.", isCorrection: true, assessable: true, holdSeconds: 0)
            }
        }
        return AnalysisResult(reps: reps, feedback: guide.checks, isCorrection: false, assessable: true, holdSeconds: 0)
    }

    private func f_point(_ f: PoseFrame, _ name: String) -> PosePoint? { f.point(name) }
}
