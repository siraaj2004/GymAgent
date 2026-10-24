import Foundation

/// Documented nutrition maths. Assumptions are always shown in the UI.
/// - BMR: Mifflin-St Jeor when sex is known; when sex is skipped, the mean of the
///   male and female equations (a less-specific estimate, as requested).
/// - TDEE = BMR x activity multiplier. Goal adjustment is modest and never extreme.
struct NutritionTargets: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
    var bmr: Double
    var tdee: Double
    var assumption: String
}

enum NutritionCalculator {
    static func activityMultiplier(_ level: String) -> Double {
        switch level {
        case "Sedentary": return 1.2
        case "Lightly active": return 1.375
        case "Moderately active": return 1.55
        case "Very active": return 1.725
        default: return 1.9
        }
    }

    static func goalAdjustment(_ goal: String) -> Double {
        switch goal {
        case "Fat loss": return -400
        case "Muscle gain": return 300
        case "Lean bulk": return 200
        case "Strength improvement": return 200
        default: return 0 // Maintenance
        }
    }

    static func proteinPerKg(_ goal: String) -> Double {
        switch goal {
        case "Fat loss": return 2.0
        case "Muscle gain", "Lean bulk", "Strength improvement": return 1.8
        default: return 1.6
        }
    }

    static func calculate(age: Int, weightKg: Double, heightCm: Double, sex: String?, activityLevel: String, goal: String) -> NutritionTargets {
        let maleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        let femaleBMR = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        let bmr: Double
        let sexNote: String
        if sex == "Male" { bmr = maleBMR; sexNote = "Mifflin-St Jeor (male)" }
        else if sex == "Female" { bmr = femaleBMR; sexNote = "Mifflin-St Jeor (female)" }
        else { bmr = (maleBMR + femaleBMR) / 2; sexNote = "Mifflin-St Jeor, sex skipped: mean of male/female equations" }
        let tdee = bmr * activityMultiplier(activityLevel)
        let calories = max(1200, tdee + goalAdjustment(goal))
        let protein = weightKg * proteinPerKg(goal)
        let fat = calories * 0.27 / 9
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4)
        let fibre = calories / 1000 * 14
        return NutritionTargets(
            calories: calories.rounded(), protein: protein.rounded(), carbs: carbs.rounded(),
            fat: fat.rounded(), fibre: fibre.rounded(), bmr: bmr.rounded(), tdee: tdee.rounded(),
            assumption: "\(sexNote); activity x\(activityMultiplier(activityLevel)); goal adjustment \(goalAdjustment(goal) >= 0 ? "+" : "")\(Int(goalAdjustment(goal))) kcal. Macros check: protein x4 + carbs x4 + fat x9 is within rounding of the calorie target by construction (carbs are the remainder)."
        )
    }
}
