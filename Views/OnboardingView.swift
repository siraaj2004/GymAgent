import SwiftUI
import SwiftData

/// Onboarding asks the questions one at a time, saves once, and never repeats:
/// GymAIApp only shows this view while `hasCompletedOnboarding` is false.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var done = false
    @State private var step = 0
    @State private var name = ""
    @State private var age = ""
    @State private var sex = "Skip"
    @State private var weight = ""
    @State private var height = ""
    @State private var targetWeight = ""
    @State private var goal = "Muscle gain"
    @State private var activity = "Moderately active"
    @State private var days = 5.0
    @State private var gymTime = Date()
    @State private var injuries = ""
    @State private var foods = ""
    @State private var budget = ""
    @State private var language = "English"

    private let goals = ["Muscle gain", "Lean bulk", "Fat loss", "Maintenance", "Strength improvement"]
    private let activities = ["Sedentary", "Lightly active", "Moderately active", "Very active", "Extremely active"]
    private let languages = ["English", "Telugu", "Hindi", "Mixed Telugu and English"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("GYM AI").font(.largeTitle).bold().foregroundColor(GymTheme.accent)
            Text("Welcome to GYM AI! I'm your personal fitness coach. Let's build your personalized fitness journey.")
                .font(.title3)
            // Easy to use: always show where you are, and that nothing here is permanent.
            Text("Step \(step + 1) of 14 · One question at a time · You can change this later")
                .font(.headline).foregroundColor(GymTheme.accent)
            ProgressBar(value: Double(step + 1), total: 14)
            Spacer()
            Group {
                switch step {
                case 0: field("What is your name?", text: $name)
                case 1: field("What is your age?", text: $age, keyboard: .numberPad)
                case 2: Picker("Biological sex for calorie estimation (you can skip)", selection: $sex) {
                    Text("Skip").tag("Skip"); Text("Female").tag("Female"); Text("Male").tag("Male")
                }.pickerStyle(.segmented)
                case 3: field("Current weight (kg)", text: $weight, keyboard: .decimalPad)
                case 4: field("Height (cm)", text: $height, keyboard: .decimalPad)
                case 5: field("Target weight (kg)", text: $targetWeight, keyboard: .decimalPad)
                case 6: Picker("Fitness goal", selection: $goal) { ForEach(goals, id: \.self) { Text($0) } }
                case 7: Picker("Activity level", selection: $activity) { ForEach(activities, id: \.self) { Text($0) } }
                case 8: VStack(alignment: .leading) { Text("How many days per week do you train? \(Int(days))"); Slider(value: $days, in: 1...7, step: 1) }
                case 9: DatePicker("What time do you usually go to the gym?", selection: $gymTime, displayedComponents: .hourAndMinute)
                case 10: field("Any injuries, mobility limitations, or medical restrictions?", text: $injuries)
                case 11: field("What foods do you prefer?", text: $foods)
                case 12: field("What is your daily food budget?", text: $budget)
                default: Picker("Which language should your trainer speak?", selection: $language) { ForEach(languages, id: \.self) { Text($0) } }
                }
            }
            Spacer()
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                Button(step == 13 ? "Finish" : "Next") {
                    if step == 13 { save() } else { step += 1 }
                }
                .buttonStyle(.borderedProminent).tint(GymTheme.accent)
                .controlSize(.large).font(.title3)
            }
        }.padding().background(GymTheme.background).foregroundColor(.white)
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading) { Text(label).font(.headline); TextField(label, text: text).keyboardType(keyboard).textFieldStyle(.roundedBorder) }
    }

    private func save() {
        let p = UserProfile()
        p.name = name; p.age = Int(age) ?? 25; p.sex = sex == "Skip" ? nil : sex
        p.weightKg = Double(weight) ?? 70; p.heightCm = Double(height) ?? 170
        p.targetWeightKg = Double(targetWeight) ?? p.weightKg; p.goal = goal; p.activityLevel = activity
        p.trainingDaysPerWeek = Int(days); p.gymTime = gymTime; p.injuries = injuries
        p.foodPreferences = foods; p.dailyFoodBudget = budget; p.trainerLanguage = language
        context.insert(p)
        try? context.save()
        NotificationManager.requestPermission()
        NotificationManager.scheduleDaily(gymTime: gymTime, dayTitle: WorkoutPlanStore.dayForDate(Date()) != nil ? "today's workout" : nil, isRestDay: WorkoutPlanStore.dayForDate(Date()) == nil)
        done = true
    }
}
