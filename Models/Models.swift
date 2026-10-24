import Foundation
import SwiftData

/// User profile from onboarding. Sex is optional: nil means "skip, use a less-specific estimate".
@Model
final class UserProfile {
    var name: String = ""
    var age: Int = 25
    var sex: String? // "Female", "Male", or nil (skipped)
    var weightKg: Double = 70
    var heightCm: Double = 170
    var targetWeightKg: Double = 70
    var goal: String = "Muscle gain"
    var activityLevel: String = "Moderately active"
    var trainingDaysPerWeek: Int = 5
    var gymTime: Date = Date()
    var injuries: String = ""
    var foodPreferences: String = ""
    var dailyFoodBudget: String = ""
    var trainerLanguage: String = "English"
    var createdAt: Date = Date()
    init() {}
}

@Model
final class WorkoutSessionRecord {
    var dayNumber: Int = 1
    var dayTitle: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    var isComplete: Bool = false
    var notes: String = ""
    @Relationship(deleteRule: .cascade) var sets: [SetRecord] = []
    init() {}
    var durationMinutes: Double {
        guard let end = endedAt else { return 0 }
        return max(0, end.timeIntervalSince(startedAt) / 60)
    }
    var totalVolumeKg: Double { sets.reduce(0) { $0 + Double($1.reps) * $1.weightKg } }
}

@Model
final class SetRecord {
    var exerciseName: String = ""
    var setIndex: Int = 1
    var reps: Int = 0
    var weightKg: Double = 0
    var rir: String = ""
    var feedback: String = ""
    var createdAt: Date = Date()
    init() {}
}

@Model
final class FoodEntry {
    var meal: String = "Breakfast" // Breakfast, Lunch, Dinner, Snacks
    var foodName: String = ""
    var grams: Double = 100
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fibre: Double = 0
    var date: Date = Date()
    init() {}
}

@Model
final class WeightEntry {
    var weightKg: Double = 70
    var date: Date = Date()
    init() {}
}

@Model
final class WaterEntry {
    var millilitres: Int = 250
    var date: Date = Date()
    init() {}
}
