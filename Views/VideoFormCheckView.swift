import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import Vision
import UniformTypeIdentifiers

/// PhotosPicker transferable for a picked video file. A bare URL is not
/// Transferable, so the picker needs this wrapper around the file URL.
struct VideoFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { $0.url } importing: { received in
            VideoFile(url: received.file)
        }
    }
}

/// How often to sample a video: about 10 frames per second is enough for
/// rep counting and keeps a long gym video fast to analyse.
enum VideoFrameSampler {
    static func interval(nominalFPS: Float) -> Int {
        guard nominalFPS > 0 else { return 1 }
        return max(1, Int((nominalFPS / 10).rounded()))
    }
    static func estimatedSamples(durationSeconds: Double) -> Int {
        max(1, Int(durationSeconds * 10))
    }
}

/// Plain-words verdict from a finished video analysis. Pure, so it is tested.
enum VideoFormVerdict {
    /// Explicit CORRECT / WRONG label, as asked: correct only when joints were
    /// visible for most of the video and wrong-form frames were under 20%.
    static func formLabel(assessableShare: Double, correctionShare: Double) -> String {
        if assessableShare < 0.5 { return "FORM: CANNOT TELL" }
        if correctionShare < 0.2 { return "FORM: CORRECT ✓" }
        return "FORM: WRONG ✗"
    }
    static func text(assessableShare: Double, correctionShare: Double) -> String {
        if assessableShare < 0.5 {
            return "Too much of you was out of frame — re-record with the required joints visible, then check again."
        }
        if correctionShare < 0.2 { return "Good form overall." }
        if correctionShare < 0.5 { return "Form needs some work — see the corrections below." }
        return "Form needs work — fix the corrections below before adding weight."
    }
}

/// Video upload form detection: pick a recorded gym video from the photo
/// library, choose the exercise, and the app analyses it on-device with the
/// SAME joint analyser as the live AI Coach (Vision pose + UniversalExerciseAnalyzer).
/// The video is never uploaded anywhere. Same honest limits as live: the camera
/// cannot see weight, grip, machine stack, or muscle effort, and neck exercises
/// stay instructional-only.
struct VideoFormCheckView: View {
    @EnvironmentObject private var planStore: WorkoutPlanStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var exerciseName: String = "Incline DB curl"
    @State private var isAnalysing = false
    @State private var progress: Double = 0
    @State private var status = "Pick a gym video, choose the exercise, then tap Analyse video."
    @State private var reps = 0
    @State private var assessableShare = 0.0
    @State private var correctionShare = 0.0
    @State private var corrections: [String] = []
    @State private var verdict = ""
    @State private var hasResult = false

    private var allExercises: [String] {
        planStore.plan.days.flatMap { $0.exercises.map { $0.name } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Check a recorded video")
                        .font(.title2.bold())
                    Text("Upload a video of one exercise. The app checks your form from your joints, just like the live AI Coach — on your phone only, nothing is uploaded.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label(videoURL == nil ? "Pick a video" : "Pick a different video", systemImage: "video.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: pickerItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let file = try? await item.loadTransferable(type: VideoFile.self) {
                                videoURL = file.url; hasResult = false
                                status = "Video picked. Choose the exercise, then tap Analyse video."
                            } else {
                                status = "Could not read that video. Try a video from your photo library."
                            }
                        }
                    }
                    if let videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL)).frame(height: 240).cornerRadius(12)
                    }
                    Picker("Exercise", selection: $exerciseName) {
                        ForEach(allExercises, id: \.self) { Text($0) }
                    }
                    Button("Analyse video") { analyse() }
                        .buttonStyle(.borderedProminent)
                        .disabled(videoURL == nil || isAnalysing)
                    if isAnalysing {
                        ProgressView(value: progress).progressViewStyle(.linear)
                        Text(status).font(.subheadline)
                    } else if hasResult {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Result: \(exerciseName)").font(.headline)
                            Text(VideoFormVerdict.formLabel(assessableShare: assessableShare, correctionShare: correctionShare))
                                .font(.title2.bold())
                                .foregroundStyle(VideoFormVerdict.formLabel(assessableShare: assessableShare, correctionShare: correctionShare).contains("CORRECT") ? Color.green : VideoFormVerdict.formLabel(assessableShare: assessableShare, correctionShare: correctionShare).contains("WRONG") ? Color.red : Color.gray)
                            Text("Reps counted: \(reps)").font(.title3.bold())
                            Text("Joints visible: \(Int(assessableShare * 100))% of checked frames")
                            Text("Wrong-form frames: \(Int(correctionShare * 100))%")
                            Text(verdict).font(.subheadline.weight(.semibold))
                            if !corrections.isEmpty {
                                Text("Corrections seen:").font(.headline)
                                ForEach(corrections, id: \.self) { Text("• \($0)").font(.subheadline) }
                            }
                        }
                        .padding().background(GymTheme.card).cornerRadius(12)
                    } else {
                        Text(status).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Honest limit: this checks joint positions only. It cannot see the weight you used, your grip, the machine stack, or how hard your muscles worked. If joints are out of frame for most of the video, it will say so instead of guessing.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Video Check")
        }
    }

    private func requiredJoints(for guide: ExerciseGuide?) -> [String] {
        guard let guide else { return ["lShoulder", "lHip", "lAnkle"] }
        if guide.pattern == .jointAngle, guide.joint == "elbow" { return ["lShoulder", "lElbow", "lWrist"] }
        if guide.pattern == .jointAngle, guide.joint == "knee" { return ["lHip", "lKnee", "lAnkle"] }
        if guide.pattern == .jointAngle { return ["lShoulder", "lHip", "lKnee"] }
        if guide.pattern == .armHeight { return ["lShoulder", "lWrist"] }
        if guide.pattern == .wristDistance { return ["lWrist", "rWrist"] }
        if guide.pattern == .ankleDistance { return ["lAnkle", "rAnkle"] }
        if guide.pattern == .verticalLift { return ["lAnkle", "lWrist", "lShoulder"] }
        return ["lShoulder", "lHip", "lAnkle"]
    }

    private func analyse() {
        guard let videoURL else { return }
        isAnalysing = true; hasResult = false; progress = 0
        status = "Analysing… this runs on your phone, frame by frame."
        let name = exerciseName
        let required = requiredJoints(for: AllExerciseGuide.guide(for: name))
        Task.detached(priority: .userInitiated) { [videoURL, name, required] in
            let asset = AVAsset(url: videoURL)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
                await MainActor.run { self.status = "No video track found in that file."; self.isAnalysing = false }
                return
            }
            let fps = (try? await track.load(.nominalFrameRate)) ?? 30
            let interval = VideoFrameSampler.interval(nominalFPS: fps)
            let duration = (try? await asset.load(.duration))?.seconds ?? 0
            let expected = VideoFrameSampler.estimatedSamples(durationSeconds: duration)
            guard let reader = try? AVAssetReader(asset: asset) else {
                await MainActor.run { self.status = "Could not read that video."; self.isAnalysing = false }
                return
            }
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            reader.add(output)
            reader.startReading()
            let analyzer = UniversalExerciseAnalyzer(exerciseName: name)
            var index = 0, checked = 0, assessable = 0, correctionsCount = 0
            var seen: [String] = []
            while let sample = output.copyNextSampleBuffer() {
                defer { index += 1 }
                guard index % interval == 0,
                      let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
                let request = PoseDetector.request()
                let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
                try? handler.perform([request])
                guard let obs = request.results?.first else { continue }
                let frame = PoseDetector.frame(from: obs, required: required)
                let result = analyzer.update(frame: frame)
                checked += 1
                if result.assessable { assessable += 1 }
                if result.isCorrection {
                    correctionsCount += 1
                    if !seen.contains(result.feedback) { seen.append(result.feedback) }
                }
                let done = Double(checked) / Double(max(expected, 1))
                await MainActor.run { self.progress = min(done, 1) }
            }
            reader.cancelReading()
            let aShare = checked > 0 ? Double(assessable) / Double(checked) : 0
            let cShare = checked > 0 ? Double(correctionsCount) / Double(checked) : 0
            let finalReps = analyzer.reps
            let finalCorrections = seen.filter { !$0.contains("Unable to assess") }
            let finalVerdict = VideoFormVerdict.text(assessableShare: aShare, correctionShare: cShare)
            await MainActor.run {
                self.reps = finalReps; self.assessableShare = aShare; self.correctionShare = cShare
                self.corrections = finalCorrections; self.verdict = finalVerdict
                self.hasResult = true; self.isAnalysing = false; self.progress = 1
                self.status = checked == 0 ? "No person was detected in that video." : "Done — \(checked) frames checked."
            }
        }
    }
}
