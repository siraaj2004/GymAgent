import Foundation

struct PlanExercise: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var muscles: String
    var sets: Int
    var reps: String
    var rest: String
    var effort: String
    var note: String?
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id: Int { day }
    var day: Int
    var title: String
    var focus: String
    var weekday: String
    var exercises: [PlanExercise]
    var note: String?
}

struct RestDay: Codable {
    var day: Int; var title: String; var weekday: String; var note: String
}

struct WorkoutPlan: Codable {
    var source: String
    var sessionMinutes: Int
    var rule: String
    var progression: String
    var days: [PlanDay]
    var restDays: [RestDay]
}

/// Loads the bundled plan (the PDF transcription). User edits, replacements and
/// incomplete-workout notes are stored separately in UserDefaults so the bundled
/// original can always be restored exactly.
final class WorkoutPlanStore: ObservableObject {
    @Published var plan: WorkoutPlan
    @Published var replacedExerciseNames: Set<String> = []

    init() {
        guard let url = Bundle.main.url(forResource: "workout-plan", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WorkoutPlan.self, from: data) else {
            fatalError("GymAI: bundled workout-plan.json missing or invalid")
        }
        self.plan = decoded
    }

    /// Monday = Day 1 … Friday = Day 5, Saturday/Sunday = rest. Matches the PDF split.
    static func dayForDate(_ date: Date) -> Int? {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sunday
        switch weekday {
        case 2: return 1; case 3: return 2; case 4: return 3; case 5: return 4; case 6: return 5
        default: return nil
        }
    }

    func day(_ number: Int) -> PlanDay? { plan.days.first { $0.day == number } }
    func today() -> PlanDay? { guard let n = Self.dayForDate(Date()) else { return nil }; return day(n) }
    func restMessage() -> String { "Today is recovery day. Focus on sleep, nutrition and hydration." }
    func restoreOriginal() { replacedExerciseNames.removeAll() }
}
