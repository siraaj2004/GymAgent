import Foundation
import UIKit
import Vision

/// Automatic food detection, on-device, using Apple's built-in Vision
/// image classifier (VNClassifyImageRequest). No photo is uploaded, no
/// API key is needed, and no extra model file is bundled.
///
/// HOW IT WORKS: Vision returns its top labels for the photo (for example
/// "banana", "rice", "egg") with a confidence percentage. matchFood maps
/// those labels to the closest item in FoodDatabase. If a label matches,
/// PhotoFoodView auto-selects that food — that is the automatic detection.
///
/// HONEST LIMITS, DO NOT OVERCLAIM:
/// - The built-in classifier covers hundreds of common objects, it is NOT
///   trained specifically for Indian food. A thali, dal, chapati or dosa
///   may be labelled "curry", "bread", "pancake" or something generic,
///   or not recognised at all. That is why the app ALWAYS shows the
///   detected label + confidence and asks the user to confirm, and why
///   manual tap (quick chips / search) is always available as fallback.
/// - A detection is a guess, not a measurement. Macros are still calculated
///   from the confirmed food and grams, and are estimates.
/// - Vision classification may not run on the simulator; it is for a real iPhone.
struct DetectedFood: Identifiable {
    let id = UUID()
    var label: String
    var confidence: Double
    var matchedFood: FoodItem?
}

enum FoodPhotoDetector {
    /// Pure mapping, testable without Vision or a photo.
    /// Returns nil when the label is not in the food database — then the
    /// user must tap the correct food, instead of the app guessing wrong.
    static func matchFood(for identifier: String) -> FoodItem? {
        let id = identifier.lowercased()
        let pairs: [(String, String)] = [
            ("rice", "Cooked rice"),
            ("banana", "Banana"),
            ("egg", "Eggs"),
            ("milk", "Milk"),
            ("yogurt", "Curd / yoghurt"),
            ("yoghurt", "Curd / yoghurt"),
            ("curd", "Curd / yoghurt"),
            ("oat", "Oats"),
            ("peanut", "Peanuts"),
            ("chicken", "Chicken breast"),
            ("biryani", "Chicken biryani"),
            ("paneer", "Paneer"),
            ("cheese", "Paneer"),
            ("lentil", "Dal (toor)"),
            ("dal", "Dal (toor)"),
            ("curry", "Dal (toor)"),
            ("soy", "Soya chunks"),
            ("tofu", "Soya chunks"),
            ("pancake", "Dosa"),
            ("crepe", "Dosa"),
            ("dosa", "Dosa"),
        ]
        for (keyword, foodName) in pairs where id.contains(keyword) {
            if let food = FoodDatabase.all.first(where: { $0.name == foodName }) { return food }
        }
        return nil
    }

    /// Runs Vision classification on a photo and returns the top 3 labels.
    static func classify(image: UIImage, completion: @escaping ([DetectedFood]) -> Void) {
        guard let cgImage = image.cgImage else { completion([]); return }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let request = VNClassifyImageRequest { request, _ in
            let results = (request.results as? [VNClassificationObservation] ?? []).prefix(3).map { obs in
                DetectedFood(label: obs.identifier, confidence: Double(obs.confidence), matchedFood: matchFood(for: obs.identifier))
            }
            DispatchQueue.main.async { completion(results) }
        }
        // NOTE: VNClassifyImageRequest has no imageCropAndScaleOption member
        // in the Xcode 16.4 SDK, so no crop option is set here — Vision uses
        // its default scaling and the classifier still runs as intended.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch { DispatchQueue.main.async { completion([]) } }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
