import Foundation
import Vision
import CoreGraphics

/// One body landmark in normalised image coordinates (0...1, origin bottom-left in Vision space).
struct PosePoint { var x: Double; var y: Double; var confidence: Double }

/// Result of one camera frame. `assessable` is false when too few landmarks are
/// confident or key joints are occluded — the UI then shows "Unable to assess"
/// instead of guessing, and no rep is counted.
struct PoseFrame {
    var points: [String: PosePoint] = [:]
    var assessable: Bool { requiredConfidenceMet }
    private var requiredConfidenceMet: Bool
    init(points: [String: PosePoint], required: [String]) {
        self.points = points
        let ok = required.allSatisfy { (points[$0]?.confidence ?? 0) >= 0.3 }
        self.requiredConfidenceMet = ok && points.count >= 8
    }
    func point(_ name: String) -> PosePoint? { points[name] }
}

enum PoseDetector {
    /// Maps Vision joint names to short keys used by ExerciseAnalyzer.
    static let jointMap: [VNHumanBodyPoseObservation.JointName: String] = [
        .neck: "neck", .leftShoulder: "lShoulder", .rightShoulder: "rShoulder",
        .leftElbow: "lElbow", .rightElbow: "rElbow", .leftWrist: "lWrist", .rightWrist: "rWrist",
        .leftHip: "lHip", .rightHip: "rHip", .leftKnee: "lKnee", .rightKnee: "rKnee",
        .leftAnkle: "lAnkle", .rightAnkle: "rAnkle", .root: "root",
    ]

    static func request() -> VNDetectHumanBodyPoseRequest { VNDetectHumanBodyPoseRequest() }

    /// Convert a Vision observation into a PoseFrame. Pure and unit-testable via PoseFrame init.
    static func frame(from observation: VNHumanBodyPoseObservation, required: [String]) -> PoseFrame {
        var points: [String: PosePoint] = [:]
        guard let recognized = try? observation.recognizedPoints(.all) else {
            return PoseFrame(points: [:], required: required)
        }
        for (joint, key) in jointMap {
            if let p = recognized[joint], p.confidence > 0 {
                points[key] = PosePoint(x: Double(p.location.x), y: Double(p.location.y), confidence: Double(p.confidence))
            }
        }
        return PoseFrame(points: points, required: required)
    }

    /// Camera-position guidance shown before tracking starts, per exercise family.
    static func cameraGuidance(for exerciseName: String) -> String {
        let n = exerciseName.lowercased()
        if n.contains("squat") || n.contains("lunge") || n.contains("deadlift") {
            return "Place the phone to your side, full body in frame, knees and hips visible."
        }
        if n.contains("push") || n.contains("plank") {
            return "Place the phone to your side at floor level, head to feet in frame."
        }
        if n.contains("pull") { return "Place the phone in front, upper body and arms fully visible." }
        if n.contains("curl") || n.contains("press") || n.contains("raise") {
            return "Place the phone in front, shoulders, elbows and wrists visible."
        }
        return "Place the phone so the joints for this exercise are fully visible, with good light."
    }
}
