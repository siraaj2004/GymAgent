import SwiftUI
import SwiftData
import AVFoundation
import Vision

/// Live camera tab. Real AVFoundation + Vision pose request; skeleton overlay is
/// drawn from the actual detected points. If points are missing, the UI says
/// "Unable to assess" and no rep is counted. Touch controls are always available
/// as a fallback for voice commands.
struct AICoachView: View {
    var exerciseName: String = "Back squat / hack squat"
    @EnvironmentObject private var coach: VoiceCoach
    @EnvironmentObject private var planStore: WorkoutPlanStore
    @Query private var profiles: [UserProfile]
    @State private var analyzer: UniversalExerciseAnalyzer?
    @State private var feedback = "Position your phone, then tap Start."
    @State private var reps = 0
    @State private var isRunning = false
    @State private var assessable = true
    @State private var cameraDenied = false
    @State private var useFrontCamera = true

    var body: some View {
        VStack(spacing: 16) {
            Text("AI Coach").font(.largeTitle).bold()
            Text(exerciseName).font(.headline)
            Text(PoseDetector.cameraGuidance(for: exerciseName)).foregroundColor(GymTheme.secondaryText)
            ZStack {
                CameraPreviewView(useFrontCamera: useFrontCamera, onFrame: handleFrame)
                    .frame(height: 320).cornerRadius(16)
                if !assessable {
                    Text("Unable to assess").padding().background(Color.black.opacity(0.7)).cornerRadius(10)
                }
            }
            Text("Reps: \(reps)").font(.system(size: 48, weight: .bold)).foregroundColor(GymTheme.accent)
            Text(feedback).multilineTextAlignment(.center)
            // Honest per-exercise limits: what the camera checks, and what it cannot check.
            if let guide = analyzer?.guide {
                Text("Camera checks: \(guide.checks)").font(.caption).foregroundColor(GymTheme.secondaryText).multilineTextAlignment(.center)
                Text("Camera cannot check: \(guide.cannotCheck)").font(.caption).foregroundColor(.yellow).multilineTextAlignment(.center)
            }
            HStack {
                Button(isRunning ? "Pause" : "Start camera") { isRunning.toggle() }
                Button("+1 rep by hand") { reps += 1 }
                Button("Finish") { isRunning = false; coach.stop() }
            }.buttonStyle(.borderedProminent).tint(GymTheme.accent).controlSize(.large)
            Button(useFrontCamera ? "Switch to back camera" : "Switch to front camera") { useFrontCamera.toggle() }
                .buttonStyle(.bordered).tint(GymTheme.accent).controlSize(.large)
            HStack {
                Toggle("Mute voice", isOn: $coach.isMuted)
                Button("How many reps?") { coach.speak("You have done \(reps) repetitions.", language: profiles.first?.trainerLanguage ?? "English") }
            }
            Text("Safety: camera analysis cannot detect every error. A movement is never called safe just because no error was detected. For heavy lifts, feedback is conservative. Stop for sharp pain, dizziness or numbness.")
                .font(.caption).foregroundColor(GymTheme.secondaryText)
            if cameraDenied { Text("Camera permission was denied. Allow Camera in iPhone Settings > GYM AI, or use manual counting.").foregroundColor(.red) }
            Spacer()
        }.padding().background(GymTheme.background)
        .onAppear { analyzer = UniversalExerciseAnalyzer(exerciseName: exerciseName) }
        .onChange(of: exerciseName) { analyzer = UniversalExerciseAnalyzer(exerciseName: $0) }
    }

    private func handleFrame(_ observation: VNHumanBodyPoseObservation) {
        guard isRunning, let analyzer else { return }
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
        let result = analyzer.update(frame: frame)
        DispatchQueue.main.async {
            self.reps = result.reps; self.feedback = result.feedback; self.assessable = result.assessable
            let language = self.profiles.first?.trainerLanguage ?? "English"
            if result.isCorrection { coach.speakCorrection(result.feedback, language: language) }
            else if result.feedback == "Good repetition!" { coach.speakCorrection("Good repetition!", language: language) }
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
