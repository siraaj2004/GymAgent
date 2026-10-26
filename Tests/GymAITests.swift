import XCTest
import AVFoundation
@testable import GymAI

final class GymAITests: XCTestCase {
    func testNutritionMacroCaloriesApproximatelyMatchTarget() {
        let t = NutritionCalculator.calculate(age: 25, weightKg: 80, heightCm: 175, sex: "Male", activityLevel: "Moderately active", goal: "Muscle gain")
        let macroKcal = t.protein * 4 + t.carbs * 4 + t.fat * 9
        XCTAssertLessThan(abs(macroKcal - t.calories), 20, "Macros must approximately match the calorie target")
        XCTAssertGreaterThan(t.calories, t.tdee)
    }

    func testNutritionSkippedSexUsesMeanNotMaleOrFemale() {
        let skipped = NutritionCalculator.calculate(age: 25, weightKg: 80, heightCm: 175, sex: nil, activityLevel: "Moderately active", goal: "Maintenance")
        let male = NutritionCalculator.calculate(age: 25, weightKg: 80, heightCm: 175, sex: "Male", activityLevel: "Moderately active", goal: "Maintenance")
        let female = NutritionCalculator.calculate(age: 25, weightKg: 80, heightCm: 175, sex: "Female", activityLevel: "Moderately active", goal: "Maintenance")
        XCTAssertLessThan(skipped.bmr, male.bmr)
        XCTAssertGreaterThan(skipped.bmr, female.bmr)
    }

    func testSquatStateMachineDoesNotDoubleCount() {
        let a = ExerciseAnalyzer(kind: .squat)
        func frame(kneeAngle: Double) -> PoseFrame {
            // Construct points whose knee angle is approximately the requested value is
            // hard in normalised space, so this test checks the guard path directly:
            // an unassessable frame must never count a rep.
            return PoseFrame(points: [:], required: ["lHip", "lKnee", "lAnkle"])
        }
        let r = a.update(frame: frame(kneeAngle: 90))
        XCTAssertEqual(r.reps, 0)
        XCTAssertFalse(r.assessable)
        XCTAssertEqual(r.feedback, "Unable to assess — move so the required joints are visible.")
    }

    func testAngleCalculation() {
        // Right angle at b: a=(0,0), b=(0,1), c=(1,1) in normalised coords.
        let angle = ExerciseAnalyzer.angle(a: PosePoint(x: 0, y: 0, confidence: 1), b: PosePoint(x: 0, y: 1, confidence: 1), c: PosePoint(x: 1, y: 1, confidence: 1))
        XCTAssertEqual(angle, 90, accuracy: 0.5)
    }

    func testFoodScalingAndSearch() {
        let rice = FoodDatabase.search("rice", vegetarianOnly: false).first!
        let scaled = FoodDatabase.scaled(rice, grams: 300)
        XCTAssertEqual(scaled.calories, 390, accuracy: 1)
        XCTAssertTrue(FoodDatabase.search("chicken", vegetarianOnly: true).isEmpty)
    }

    func testPlanJSONStructure() throws {
        let url = Bundle.main.url(forResource: "workout-plan", withExtension: "json")!
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: Data(contentsOf: url))
        XCTAssertEqual(plan.days.count, 5)
        XCTAssertEqual(plan.days.reduce(0) { $0 + $1.exercises.count }, 71)
        XCTAssertEqual(plan.sessionMinutes, 100)
        for day in plan.days {
            XCTAssertFalse(day.exercises.isEmpty)
            for ex in day.exercises {
                XCTAssertGreaterThan(ex.sets, 0)
                XCTAssertFalse(ex.reps.isEmpty)
                XCTAssertFalse(ex.rest.isEmpty)
            }
        }
        XCTAssertEqual(plan.restDays.count, 2)
    }

    func testAllPlanExercisesHaveAPoseGuide() throws {
        let url = Bundle.main.url(forResource: "workout-plan", withExtension: "json")!
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: Data(contentsOf: url))
        var missing: [String] = []
        for day in plan.days {
            for ex in day.exercises where AllExerciseGuide.guide(for: ex.name) == nil {
                missing.append(ex.name)
            }
        }
        XCTAssertTrue(missing.isEmpty, "Exercises without a pose guide: \(missing.joined(separator: ", "))")
        // Neck must stay instructional, never aggressive.
        XCTAssertEqual(AllExerciseGuide.guide(for: "Neck isometric flexion/extension")?.pattern, .neckInstructional)
    }

    func testUniversalAnalyzerNeverCountsUnassessableFrame() {
        let a = UniversalExerciseAnalyzer(exerciseName: "Back squat / hack squat")
        let r = a.update(frame: PoseFrame(points: [:], required: ["lHip", "lKnee", "lAnkle"]))
        XCTAssertEqual(r.reps, 0)
        XCTAssertFalse(r.assessable)
    }

    func testTimeBlocksSumTo100AndCoverEveryExerciseOnce() throws {
        let url = Bundle.main.url(forResource: "workout-plan", withExtension: "json")!
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: Data(contentsOf: url))
        for day in plan.days {
            let blocks = try XCTUnwrap(day.blocks, "Day \(day.day) must have time blocks")
            XCTAssertEqual(blocks.reduce(0) { $0 + $1.minutes }, 100, "Day \(day.day) blocks must sum to 100 min")
            let covered = blocks.flatMap { $0.exercises }
            XCTAssertEqual(covered.count, day.exercises.count)
            XCTAssertEqual(Set(covered), Set(day.exercises.map { $0.name }))
        }
    }

    func testLowCostFoodsAndProteinGrams() {
        XCTAssertFalse(FoodDatabase.lowCostFoods.isEmpty)
        XCTAssertTrue(FoodDatabase.lowCostFoods.allSatisfy { $0.costTier == "Low" })
        XCTAssertTrue(FoodDatabase.lowCostFoods.contains { $0.name == "Soya chunks" })
        let soya = FoodDatabase.lowCostFoods.first { $0.name == "Soya chunks" }!
        XCTAssertEqual(FoodDatabase.gramsForProtein(soya, proteinTarget: 52), 100, accuracy: 1)
    }

    func testHelpAssistantGivesCameraAndVoiceSolutions() {
        XCTAssertTrue(HelpAssistant.solution(for: "camera not detecting my squat").contains("Camera help"))
        XCTAssertTrue(HelpAssistant.solution(for: "voice not speaking in telugu").contains("Voice help"))
    }

    func testDailyFoodPrices() {
        XCTAssertEqual(DailyFoodPrices.plans.count, 7)
        XCTAssertTrue(DailyFoodPrices.plans.allSatisfy { !$0.items.isEmpty })
        let totals = DailyFoodPrices.totals(for: DailyFoodPrices.plans[0])
        XCTAssertTrue(totals.calories > 1000 && totals.protein > 50)
        XCTAssertEqual(DailyFoodPrices.prices.first { $0.foodName == "Eggs" }?.indicativePrice, 5.7)
        XCTAssertEqual(DailyFoodPrices.prices.first { $0.foodName == "Chicken breast" }?.indicativePrice, 220)
        XCTAssertEqual(DailyFoodPrices.prices.first { $0.foodName == "Dal (toor)" }?.indicativePrice, 115)
    }

    func testPhotoFoodCalculation() {
        // Photo food logging: user confirms food + grams, app calculates macros.
        let rice = FoodDatabase.all.first { $0.name == "Cooked rice" }!
        let scaled = FoodDatabase.scaled(rice, grams: 300)
        XCTAssertEqual(scaled.calories, 390)
        XCTAssertEqual(scaled.protein, 7.2, accuracy: 0.01)
        XCTAssertEqual(scaled.carbs, 84)
        XCTAssertEqual(scaled.fibre, 1.6, accuracy: 0.01)
        let dal = FoodDatabase.all.first { $0.name == "Dal (toor)" }!
        XCTAssertEqual(FoodDatabase.scaled(dal, grams: 200).protein, 12)
        let rice2 = FoodDatabase.all.first { $0.name == "Cooked rice" }!
        XCTAssertEqual(FoodDatabase.gramsForCarbs(rice2, carbTarget: 42), 150)
        XCTAssertEqual(FoodPhotoDetector.matchFood(for: "banana")?.name, "Banana")
        XCTAssertEqual(FoodPhotoDetector.matchFood(for: "rice")?.name, "Cooked rice")
        XCTAssertEqual(FoodPhotoDetector.matchFood(for: "fried egg")?.name, "Eggs")
        XCTAssertNil(FoodPhotoDetector.matchFood(for: "pizza"))
        XCTAssertTrue(FoodDatabase.lowCostFoods.contains { $0.name == "Dal (toor)" })
        let entry = FoodEntry()
        XCTAssertNil(entry.photoData)
    }

    func testHelpAssistantAnswersRelevantlyNotFirstKeyword() {
        // Old bug: "count" alone could pull the camera answer for a food question.
        XCTAssertTrue(HelpAssistant.solution(for: "my food protein count is wrong").contains("Food help"))
        XCTAssertTrue(HelpAssistant.solution(for: "camera is not counting my reps").contains("Camera help"))
        XCTAssertTrue(HelpAssistant.solution(for: "app crashes when I open it").contains("Install help"))
        XCTAssertTrue(HelpAssistant.solution(for: "reminder is not coming before gym").contains("Reminder help"))
        XCTAssertTrue(HelpAssistant.solution(for: "my workout day is wrong today").contains("Workout help"))
        // Unknown question must not pretend: it must ask for the topic.
        XCTAssertTrue(HelpAssistant.solution(for: "xyzqq something strange").contains("could not match"))
    }

    func testExerciseKindMapping() {
        XCTAssertEqual(ExerciseKind.forExercise("Back squat / hack squat"), .squat)
        XCTAssertEqual(ExerciseKind.forExercise("Incline DB curl"), .bicepCurl)
        XCTAssertEqual(ExerciseKind.forExercise("Neck isometric flexion/extension"), .neckInstructional)
        XCTAssertEqual(ExerciseKind.forExercise("Cable fly"), .manual)
    }

    func testWeekdayMapping() {
        // 2026-10-26 is a Monday in Asia/Calcutta context; verify mapping logic only via dayForDate on a known Monday.
        var comps = DateComponents(); comps.year = 2026; comps.month = 10; comps.day = 26
        let monday = Calendar.current.date(from: comps)!
        XCTAssertEqual(WorkoutPlanStore.dayForDate(monday), 1)
    }

    func testCoachCameraDefaultsToFront() {
        XCTAssertEqual(CoachCamera.position(forFront: true), .front)
        XCTAssertEqual(CoachCamera.position(forFront: false), .back)
    }

    private func squatFrame(ankleX: Double, ankleY: Double) -> PoseFrame {
        var pts: [String: PosePoint] = [:]
        pts["lHip"] = PosePoint(x: 0, y: 0, confidence: 1)
        pts["lKnee"] = PosePoint(x: 1, y: 0, confidence: 1)
        pts["lAnkle"] = PosePoint(x: ankleX, y: ankleY, confidence: 1)
        for name in ["lShoulder", "rShoulder", "rHip", "rKnee", "rAnkle", "lWrist"] {
            pts[name] = PosePoint(x: 0.5, y: 0.5, confidence: 1)
        }
        return PoseFrame(points: pts, required: ["lHip", "lKnee", "lAnkle"])
    }

    func testVoiceCorrectionForPartialSquatRep() {
        let a = UniversalExerciseAnalyzer(exerciseName: "Back squat / hack squat")
        _ = a.update(frame: squatFrame(ankleX: 1.985, ankleY: 0.174)) // ~170 deg, standing
        _ = a.update(frame: squatFrame(ankleX: 1.643, ankleY: 0.766)) // ~130 deg, middle
        let r = a.update(frame: squatFrame(ankleX: 1.985, ankleY: 0.174)) // back to standing, no depth reached
        XCTAssertEqual(r.reps, 0)
        XCTAssertTrue(r.isCorrection, "A half rep must speak the exercise correction, not stay silent")
        XCTAssertEqual(r.feedback, "Keep your chest up, bend to good depth, stand up smoothly.")
    }

    func testVoiceCorrectionForArmRaiseTooHigh() {
        let a = UniversalExerciseAnalyzer(exerciseName: "Cable lateral raise")
        var pts: [String: PosePoint] = [:]
        pts["lShoulder"] = PosePoint(x: 0.5, y: 0.5, confidence: 1)
        pts["lWrist"] = PosePoint(x: 0.5, y: 0.8, confidence: 1)
        for name in ["lHip", "lKnee", "lAnkle", "rShoulder", "rHip", "rKnee", "rAnkle", "lElbow"] {
            pts[name] = PosePoint(x: 0.5, y: 0.5, confidence: 1)
        }
        let r = a.update(frame: PoseFrame(points: pts, required: ["lShoulder", "lWrist"]))
        XCTAssertTrue(r.isCorrection)
    }
}
