import SwiftUI
import SwiftData
import AVFoundation
import Vision

/// Form status for the compact rep panel. "Good" is never a safety claim:
/// it only means the visible joints matched the rep pattern with no
/// correction in the latest assessed frame.
enum CoachFormStatus: Equatable {
    case good, correction, stop, notDetected
    var label: String {
        switch self {
        case .good: return "GOOD"
        case .correction: return "CORRECTION"
        case .stop: return "STOP"
        case .notDetected: return "NOT DETECTED"
        }
    }
    var color: Color {
        switch self {
        case .good: return GymTheme.accent
        case .correction: return .yellow
        case .stop: return .red
        case .notDetected: return .gray
        }
    }
    static func status(isRunning: Bool, assessable: Bool, isCorrection: Bool, feedback: String) -> CoachFormStatus {
        if !assessable { return .notDetected }
        let lower = feedback.lowercased()
        if lower.contains("pain") { return .stop }
        if !isRunning { return .notDetected }
        if isCorrection { return .correction }
        return .good
    }
}

/// Target reps from the plan's reps string, e.g. "6-8" -> 8, "12-15" -> 15.
/// Nil when the exercise has no plan entry, so the panel shows reps alone
/// rather than inventing a target.
enum CoachTargetReps {
    static func target(from repsString: String) -> Int? {
        repsString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init).max()
    }
}

/// Maps a Vision pose point to a screen point for the skeleton overlay.
/// Vision y grows upward, screen y grows downward, so y is flipped.
/// The front camera preview is mirrored, so x is flipped for the front camera.
/// This is an approximation under resizeAspectFill: the camera and the screen
/// have similar portrait ratios, so alignment is close, not pixel-perfect.
enum SkeletonPointMapper {
    static func position(for point: PosePoint, size: CGSize, mirrored: Bool) -> CGPoint {
        let x = (mirrored ? 1 - point.x : point.x) * size.width
        let y = (1 - point.y) * size.height
        return CGPoint(x: x, y: y)
    }
}

/// Skeleton overlay: dots + lines for the joints Vision actually detected,
/// drawn on top of the camera preview. Only detected joints are drawn — a
/// joint with no point is simply absent, never guessed.
/// Colour shows FORM, as asked: green when the form is correct, red when
/// the form is wrong (a correction is active). A joint Vision is not
/// confident about (< 0.3) stays grey, whatever the form — it is not
/// claimed as correct or wrong.
struct SkeletonOverlayView: View {
    var points: [String: PosePoint]
    var size: CGSize
    var mirrored: Bool
    var isWrong: Bool
    var assessable: Bool
    private static let connections: [(String, String)] = [
        ("lShoulder", "rShoulder"), ("lShoulder", "lElbow"), ("lElbow", "lWrist"),
        ("rShoulder", "rElbow"), ("rElbow", "rWrist"),
        ("lShoulder", "lHip"), ("rShoulder", "rHip"), ("lHip", "rHip"),
        ("lHip", "lKnee"), ("lKnee", "lAnkle"),
        ("rHip", "rKnee"), ("rKnee", "rAnkle"),
    ]
    private func pos(_ name: String) -> CGPoint? {
        guard let p = points[name], p.confidence > 0 else { return nil }
        return SkeletonPointMapper.position(for: p, size: size, mirrored: mirrored)
    }
    private func color(for point: PosePoint) -> Color {
        if point.confidence < 0.3 { return .gray }
        if !assessable { return .gray }
        if isWrong { return .red }
        return GymTheme.accent
    }
    private var lineColor: Color {
        if !assessable { return Color.gray.opacity(0.5) }
        return isWrong ? .red : GymTheme.accent
    }
    var body: some View {
        ZStack {
            Path { path in
                for (a, b) in Self.connections {
                    if let pa = pos(a), let pb = pos(b),
                       (points[a]?.confidence ?? 0) >= 0.3, (points[b]?.confidence ?? 0) >= 0.3 {
                        path.move(to: pa); path.addLine(to: pb)
                    }
                }
            }.stroke(lineColor.opacity(0.8), lineWidth: 2)
            ForEach(Array(points.keys.sorted()), id: \.self) { name in
                if let p = points[name], p.confidence > 0 {
                    let c = SkeletonPointMapper.position(for: p, size: size, mirrored: mirrored)
                    Circle().fill(color(for: p)).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .position(c)
                }
            }
        }
    }
}

/// Live camera tab. Real AVFoundation + Vision pose request; skeleton overlay is
/// drawn from the actual detected points. If points are missing, the UI says
/// "Unable to assess" and no rep is counted. Touch controls are always available
/// as a fallback for voice commands.
///
/// Compact UI (1.9.0): the camera fills the whole screen. Only a small
/// translucent panel (~100-125 points tall, 92% of screen width) sits at the
/// bottom, above the tab bar. The exercise name is a small top label, camera
/// flip / mute are small top-right icons, and the long guidance + safety text
/// lives behind an info button — nothing large and opaque covers the body.
struct AICoachView: View {
    var exerciseName: String = "Back squat / hack squat"
    @EnvironmentObject private var coach: VoiceCoach
    @EnvironmentObject private var planStore: WorkoutPlanStore
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var analyzer: UniversalExerciseAnalyzer?
    @State private var feedback = "Position your phone, then tap Start."
    @State private var reps = 0
    @State private var isRunning = false
    @State private var assessable = true
    @State private var isCorrection = false
    @State private var cameraDenied = false
    @State private var useFrontCamera = true
    @State private var showInfo = false
    @State private var feedbackVisible = false
    @State private var feedbackToken = 0
    @State private var setAlreadySaved = false
    // UI debounce for "Unable to assess": hold the last good feedback for
    // up to 3 consecutive unassessable frames, so a brief occlusion does not
    // flicker the screen between GOOD / NOT DETECTED / CORRECTION.
    @State private var unassessableStreak = 0
    // Latest Vision pose points, for the skeleton overlay. Updated on every
    // camera frame, even before Start is tapped, so joints show as soon as
    // they come on screen.
    @State private var posePoints: [String: PosePoint] = [:]

    private var targetReps: Int? {
        planStore.plan.days.flatMap { $0.exercises }.first { $0.name == exerciseName }
            .flatMap { CoachTargetReps.target(from: $0.reps) }
    }
    private var formStatus: CoachFormStatus {
        CoachFormStatus.status(isRunning: isRunning, assessable: assessable, isCorrection: isCorrection, feedback: feedback)
    }
    private var language: String { profiles.first?.trainerLanguage ?? "English" }

    var body: some View {
        ZStack {
            // Full-screen camera: the preview fills the whole screen, not
            // a small 320-point box in the middle.
            CameraPreviewView(useFrontCamera: useFrontCamera, onFrame: handleFrame)
                .ignoresSafeArea()
            // Skeleton overlay, above the camera but below the panels:
            // green joints = correct form, red joints = wrong form.
            GeometryReader { geo in
                SkeletonOverlayView(points: posePoints, size: geo.size, mirrored: useFrontCamera, isWrong: isCorrection, assessable: assessable)
            }.ignoresSafeArea()
            VStack(spacing: 10) {
                // Small top label + top-right icons only. No large overlay.
                HStack(alignment: .top) {
                    Text(exerciseName)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.black.opacity(0.45)).cornerRadius(12)
                    Spacer()
                    HStack(spacing: 8) {
                        Button { showInfo = true } label: {
                            Image(systemName: "info.circle.fill")
                        }.accessibilityLabel("Exercise info")
                        Button { useFrontCamera.toggle() } label: {
                            Image(systemName: "camera.rotate.fill")
                        }.accessibilityLabel(useFrontCamera ? "Switch to back camera" : "Switch to front camera")
                        Button { coach.isMuted.toggle() } label: {
                            Image(systemName: coach.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        }.accessibilityLabel(coach.isMuted ? "Unmute voice" : "Mute voice")
                    }
                    .font(.title3)
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.45)).cornerRadius(22)
                }
                Spacer()
                // Short floating feedback, fading after a few seconds so the
                // body stays visible. Tracking never stops when it fades.
                if feedbackVisible {
                    Text(feedback)
                        .font(.subheadline).multilineTextAlignment(.center).lineLimit(2)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.black.opacity(0.55)).cornerRadius(12)
                        .transition(.opacity)
                }
                if cameraDenied {
                    Text("Camera permission was denied. Allow Camera in iPhone Settings > GYM AI, or use manual counting.")
                        .font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.black.opacity(0.55)).cornerRadius(12)
                }
                // Compact bottom panel: ~92% wide (16pt margins each side),
                // about 100-125 points tall, blurred dark translucent.
                VStack(spacing: 8) {
                    HStack {
                        Button { coach.speak("You have done \(reps) repetitions.", language: language) } label: {
                            HStack(spacing: 4) {
                                Text("REPS").font(.caption.weight(.semibold)).foregroundColor(.white.opacity(0.8))
                                if let target = targetReps {
                                    Text("\(reps) / \(target)").font(.title3.weight(.bold)).foregroundColor(GymTheme.accent)
                                } else {
                                    Text("\(reps)").font(.title3.weight(.bold)).foregroundColor(GymTheme.accent)
                                }
                            }
                        }.accessibilityLabel("How many reps?")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(formStatus.color).frame(width: 8, height: 8)
                            Text("FORM: \(formStatus.label)").font(.caption.weight(.bold)).foregroundColor(formStatus.color)
                        }
                    }
                    HStack(spacing: 8) {
                        Button(isRunning ? "Pause" : "Start") {
                            isRunning.toggle()
                            if isRunning { setAlreadySaved = false }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        Button("+1 Rep") {
                            reps += 1
                            setAlreadySaved = false
                            feedback = "Manual rep added."
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        Button("Finish") { finishSet() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(!isRunning && reps == 0)
                    }
                    .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.9)
                    .buttonStyle(.borderedProminent).tint(GymTheme.accent).controlSize(.large)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .onAppear { analyzer = UniversalExerciseAnalyzer(exerciseName: exerciseName) }
        .onChange(of: exerciseName) { analyzer = UniversalExerciseAnalyzer(exerciseName: $0) }
        .onChange(of: feedback) { _, _ in
            // Show the new message, then fade it after 3 seconds.
            feedbackVisible = true
            feedbackToken += 1
            let token = feedbackToken
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if token == feedbackToken { withAnimation { feedbackVisible = false } }
            }
        }
        .sheet(isPresented: $showInfo) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(exerciseName).font(.title3.weight(.bold))
                        Text(PoseDetector.cameraGuidance(for: exerciseName))
                        if let guide = analyzer?.guide {
                            Text("Camera checks: \(guide.checks)")
                            Text("Camera cannot check: \(guide.cannotCheck)").foregroundColor(.yellow)
                        }
                        Text("Safety: camera analysis cannot detect every error. A movement is never called safe just because no error was detected. For heavy lifts, feedback is conservative. Stop for sharp pain, dizziness or numbness.")
                        Button("How many reps?") { coach.speak("You have done \(reps) repetitions.", language: language) }
                            .buttonStyle(.borderedProminent).tint(GymTheme.accent)
                    }.padding()
                }
                .toolbar { Button("Done") { showInfo = false } }
            }
        }
    }

    /// Finish ends the set and saves it (once per set) to SwiftData, so the
    /// set appears in Progress like any other saved set.
    private func finishSet() {
        if reps > 0, !setAlreadySaved {
            let session = WorkoutSessionRecord()
            session.dayNumber = planStore.today()?.day ?? 1
            session.dayTitle = planStore.today()?.title ?? ""
            session.endedAt = Date()
            let record = SetRecord()
            record.exerciseName = exerciseName
            record.setIndex = 1
            record.reps = reps
            session.sets.append(record)
            context.insert(session)
            try? context.save()
            setAlreadySaved = true
            feedback = "Set saved: \(reps) reps."
        }
        isRunning = false
        coach.stop()
    }

    private func handleFrame(_ observation: VNHumanBodyPoseObservation) {
        guard let analyzer else { return }
        let guide = analyzer.guide
        var required: [String] = ["lShoulder", "lHip", "lAnkle"]
        if let guide {
            if guide.pattern == .jointAngle, guide.joint == "elbow" { required = ["lShoulder", "lElbow", "lWrist"] }
            else if guide.pattern == .jointAngle, guide.joint == "knee" { required = ["lHip", "lKnee", "lAnkle"] }
            else if guide.pattern == .jointAngle { required = ["lShoulder", "lHip", "lKnee"] }
            else if guide.pattern == .armHeight { required = ["lShoulder", "lWrist"] }
            else if guide.pattern == .wristDistance { required = ["lWrist", "rWrist"] }
            else if guide.pattern == .ankleDistance { required = ["lAnkle", "rAnkle"] }
            else if guide.pattern == .verticalLift { required = ["lAnkle", "lWrist", "lShoulder"] }
            else if guide.pattern == .bodyLineHold { required = ["lShoulder", "lHip", "lAnkle"] }
        }
        let frame = PoseDetector.frame(from: observation, required: required)
        // Skeleton overlay first: joints show as soon as they come on
        // screen, even before Start. Rep counting and corrections still
        // only run while tracking is on.
        let overlayPoints = frame.points
        DispatchQueue.main.async { self.posePoints = overlayPoints }
        guard isRunning else { return }
        let result = analyzer.update(frame: frame)
        DispatchQueue.main.async {
            let increased = result.reps > self.reps
            // Hold the last good UI state through brief dropouts.
            if !result.assessable {
                self.unassessableStreak += 1
                if self.unassessableStreak < 3 {
                    // Still count a rep if one arrived, but do not flip the
                    // screen or the voice to "Unable to assess" yet.
                    self.reps = result.reps
                    if result.isCorrection { coach.playWrongBeep() }
                    return
                }
            } else {
                self.unassessableStreak = 0
            }
            self.reps = result.reps; self.feedback = result.feedback; self.assessable = result.assessable
            self.isCorrection = result.isCorrection
            let language = self.profiles.first?.trainerLanguage ?? "English"
            if result.isCorrection {
                // Wrong position: loud beep + spoken correction for THIS
                // exercise (its own correction text, not a shared one).
                coach.playWrongBeep()
                coach.speakCorrection(result.feedback, language: language)
            }
            else if increased, let target = self.targetReps, result.reps >= target {
                coach.speakCorrection("Correct! Set complete.", language: language)
            }
            else if result.feedback == "Good repetition!" {
                // Correct position, completed rep: say so plainly.
                coach.speakCorrection("Correct! Good repetition!", language: language)
            }
        }
    }
}

/// Front camera by default (so you can see yourself while you train),
/// with a switch to the back camera. Falls back to the other camera if
/// the preferred one is not available on the device.
enum CoachCamera {
    static func position(forFront: Bool) -> AVCaptureDevice.Position { forFront ? .front : .back }
    static func device(forFront: Bool) -> AVCaptureDevice? {
        let preferred = position(forFront: forFront)
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferred) { return device }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position(forFront: !forFront))
    }
}

struct CameraPreviewView: UIViewRepresentable {
    var useFrontCamera: Bool = true
    var onFrame: (VNHumanBodyPoseObservation) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = AVCaptureSession()
        session.sessionPreset = .high
        guard let device = CoachCamera.device(forFront: useFrontCamera),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }
        session.addInput(input)
        context.coordinator.currentPosition = device.position
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "gymai.camera"))
        session.addOutput(output)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer; context.coordinator.session = session
        session.startRunning()
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
        let wanted = CoachCamera.position(forFront: useFrontCamera)
        if let session = context.coordinator.session, context.coordinator.currentPosition != wanted {
            context.coordinator.switchCamera(to: wanted, session: session)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(onFrame: onFrame) }
    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onFrame: (VNHumanBodyPoseObservation) -> Void
        var session: AVCaptureSession?
        var layer: AVCaptureVideoPreviewLayer?
        var currentPosition: AVCaptureDevice.Position?
        init(onFrame: @escaping (VNHumanBodyPoseObservation) -> Void) { self.onFrame = onFrame }
        func switchCamera(to position: AVCaptureDevice.Position, session: AVCaptureSession) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            session.beginConfiguration()
            for old in session.inputs { session.removeInput(old) }
            if session.canAddInput(input) { session.addInput(input); currentPosition = position }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
            if let obs = request.results?.first { onFrame(obs) }
        }
    }
}
