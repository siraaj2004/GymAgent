import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var done = false
    @StateObject private var planStore = WorkoutPlanStore()
    @StateObject private var coach = VoiceCoach()
    var body: some View {
        if !done { OnboardingView() }
        else {
            TabView {
                HomeView().tabItem { Label("Home", systemImage: "house") }
                WorkoutView().tabItem { Label("Workout", systemImage: "dumbbell") }
                AICoachView().tabItem { Label("AI Coach", systemImage: "camera") }
                FoodView().tabItem { Label("Food", systemImage: "fork.knife") }
                ProgressViewTab().tabItem { Label("Progress", systemImage: "chart.bar") }
            }
            .environmentObject(planStore).environmentObject(coach)
            .preferredColorScheme(.dark)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var planStore: WorkoutPlanStore
    @Query private var profiles: [UserProfile]
    @Query private var foods: [FoodEntry]
    @State private var showWorkout = false
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let p = profiles.first {
                    let t = NutritionCalculator.calculate(age: p.age, weightKg: p.weightKg, heightCm: p.heightCm, sex: p.sex, activityLevel: p.activityLevel, goal: p.goal)
                    let todayFood = foods.filter { Calendar.current.isDateInToday($0.date) }
                    let cal = todayFood.reduce(0) { $0 + $1.calories }
                    let prot = todayFood.reduce(0) { $0 + $1.protein }
                    Text("Hello, \(p.name)").font(.largeTitle).bold()
                    // Easy to use: the one thing most people want is first, big, and plain.
                    Button("▶ Start today's workout") { showWorkout = true }
                        .buttonStyle(.borderedProminent).tint(GymTheme.accent)
                        .controlSize(.large).font(.title3).frame(maxWidth: .infinity)
                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's workout").font(.headline)
                            if let day = planStore.today() {
                                Text("Day \(day.day): \(day.title)"); Text("\(day.exercises.count) exercises · \(day.exercises.reduce(0) { $0 + $1.sets }) sets · 100 min").foregroundColor(GymTheme.secondaryText)
                            } else { Text(planStore.restMessage()) }
                        }
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calories remaining: \(Int(max(0, t.calories - cal))) / \(Int(t.calories)) kcal")
                            ProgressBar(value: cal, total: t.calories)
                            Text("Protein remaining: \(Int(max(0, t.protein - prot))) / \(Int(t.protein)) g")
                            ProgressBar(value: prot, total: t.protein)
                            Text(t.assumption).font(.caption).foregroundColor(GymTheme.secondaryText)
                        }
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout reminder").font(.headline)
                            Text("Gym time: \(p.gymTime, style: .time)")
                            Button("Snooze 10 min") { NotificationManager.snooze() }
                        }
                    }
                } else { Text("No profile yet. Restart onboarding from Settings.") }
                GymCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to use GYM AI — just 3 steps").font(.headline)
                        Text("1. Tap Start today's workout.")
                        Text("2. Follow the exercise list, top to bottom. Tap Done after each set.")
                        Text("3. After the gym, tap Food and add what you ate.")
                        Text("For camera help, tap AI Coach and follow the voice. You can always tap Done by hand.")
                            .foregroundColor(GymTheme.secondaryText)
                    }
                }
            }.padding()
        }.background(GymTheme.background)
        }
        .sheet(isPresented: $showWorkout) { WorkoutView() }
    }
}

struct WorkoutView: View {
    @EnvironmentObject private var planStore: WorkoutPlanStore
    @Environment(\.modelContext) private var context
    @State private var selectedDay = WorkoutPlanStore.dayForDate(Date()) ?? 1
    @State private var session: WorkoutSessionRecord?
    @State private var completed: Set<String> = []
    @State private var painAlert = false
    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Day", selection: $selectedDay) {
                    ForEach(planStore.plan.days) { Text("Day \($0.day)").tag($0.day) }
                }.pickerStyle(.segmented)
                if let day = planStore.day(selectedDay) {
                    Text("Day \(day.day): \(day.title)").font(.title2).bold()
                    Text(day.focus).foregroundColor(GymTheme.secondaryText)
                    Text("Target: 100 minutes · \(day.exercises.count) exercises · \(day.exercises.reduce(0) { $0 + $1.sets }) sets").font(.caption)
                    // Easy to use: plain progress, no jargon.
                    Text("You have done \(completed.count) of \(day.exercises.count) exercises.")
                        .font(.headline).foregroundColor(GymTheme.accent)
                    ProgressBar(value: Double(completed.count), total: Double(day.exercises.count))
                    Button(session == nil ? "Start this workout" : "End workout & save") {
                        if session == nil {
                            let s = WorkoutSessionRecord(); s.dayNumber = day.day; s.dayTitle = day.title; context.insert(s); session = s
                        } else {
                            session?.endedAt = Date(); session?.isComplete = true
                            try? context.save(); NotificationManager.completionMessage(); session = nil
                        }
                    }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
                    Button("Stop — sharp pain / dizziness / numbness", role: .destructive) { painAlert = true }
                    ForEach(day.exercises) { ex in
                        GymCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(ex.name).font(.headline)
                                Text(ex.muscles).foregroundColor(GymTheme.secondaryText)
                                Text("\(ex.sets) sets x \(ex.reps) · Rest \(ex.rest) · \(ex.effort)")
                                if let note = ex.note { Text(note).font(.caption).foregroundColor(.yellow) }
                                HStack {
                                    Button(completed.contains(ex.name) ? "✓ Done" : "Tap when done") {
                                        completed.insert(ex.name)
                                        if let s = session {
                                            let r = SetRecord(); r.exerciseName = ex.name; r.setIndex = 1; r.reps = 10; context.insert(r); s.sets.append(r); try? context.save()
                                        }
                                    }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
                                    NavigationLink("AI Coach") { AICoachView(exerciseName: ex.name) }
                                }
                            }
                        }
                    }
                    Text("Original plan is always available: bundled workout-plan.json is the restore source.").font(.caption).foregroundColor(GymTheme.secondaryText)
                    Button("Restore original plan") { planStore.restoreOriginal() }
                }
            }.padding()
        }.background(GymTheme.background)
        }
        .alert("Stop this session", isPresented: $painAlert) {
            Button("OK — session stopped", role: .destructive) { session?.isComplete = false; try? context.save(); session = nil }
        } message: { Text("Stop the session and seek professional assessment for sharp pain, dizziness, numbness or unusual symptoms. Camera analysis never proves a movement is safe.") }
    }
}

struct FoodView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var foods: [FoodEntry]
    @State private var query = ""
    @State private var vegOnly = false
    @State private var meal = "Breakfast"
    @State private var waterMl = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Food").font(.largeTitle).bold()
                if let p = profiles.first {
                    let t = NutritionCalculator.calculate(age: p.age, weightKg: p.weightKg, heightCm: p.heightCm, sex: p.sex, activityLevel: p.activityLevel, goal: p.goal)
                    let today = foods.filter { Calendar.current.isDateInToday($0.date) }
                    let cal = today.reduce(0) { $0 + $1.calories }; let prot = today.reduce(0) { $0 + $1.protein }
                    let carb = today.reduce(0) { $0 + $1.carbs }; let fat = today.reduce(0) { $0 + $1.fat }; let fib = today.reduce(0) { $0 + $1.fibre }
                    GymCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today: \(Int(cal)) / \(Int(t.calories)) kcal · Protein \(Int(prot)) / \(Int(t.protein)) g · Carbs \(Int(carb)) / \(Int(t.carbs)) g · Fat \(Int(fat)) / \(Int(t.fat)) g · Fibre \(Int(fib)) / \(Int(t.fibre)) g")
                            Text("Remaining protein: \(Int(max(0, t.protein - prot))) g")
                        }
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AI suggestions for remaining targets").font(.headline)
                            ForEach(FoodDatabase.suggestions(remainingProtein: t.protein - prot, remainingCalories: t.calories - cal, vegetarianOnly: vegOnly)) { f in
                                Text("\(f.name) — \(f.serving): \(Int(f.calories)) kcal, \(f.protein, specifier: "%.0f") g protein")
                            }
                            Text("Values are estimates for the stated serving. Confirm or correct food and quantity before saving. Photo suggestions are suggestions only, never exact nutrition from a photo.").font(.caption).foregroundColor(GymTheme.secondaryText)
                        }
                    }
                }
                TextField("Search food (rice, chapati, chicken, dal…)", text: $query).textFieldStyle(.roundedBorder)
                Toggle("Vegetarian only", isOn: $vegOnly)
                Picker("Meal", selection: $meal) { ForEach(["Breakfast", "Lunch", "Dinner", "Snacks"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                ForEach(FoodDatabase.search(query, vegetarianOnly: vegOnly)) { item in
                    GymCard {
                        HStack {
                            VStack(alignment: .leading) { Text(item.name).font(.headline); Text("\(item.serving): \(Int(item.calories)) kcal, \(item.protein, specifier: "%.0f") g protein") }
                            Spacer()
                            Button("Add") {
                                let e = FoodEntry(); e.meal = meal; e.foodName = item.name; e.grams = item.grams
                                e.calories = item.calories; e.protein = item.protein; e.carbs = item.carbs; e.fat = item.fat; e.fibre = item.fibre
                                context.insert(e); try? context.save()
                            }
                        }
                    }
                }
                GymCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Water").font(.headline)
                        Text("\(waterMl) ml today (this session counter; add a WaterEntry in code for persistence)")
                        Button("Add 250 ml") { waterMl += 250; let w = WaterEntry(); w.millilitres = 250; context.insert(w); try? context.save() }
                    }
                }
                Text("Barcode scanning and photo meal estimation require a nutrition API / on-device model key and are not claimed as exact. Use search + manual grams for reliable logging.").font(.caption).foregroundColor(GymTheme.secondaryText)
            }.padding()
        }.background(GymTheme.background)
    }
}

struct ProgressViewTab: View {
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [WorkoutSessionRecord]
    @Query private var weights: [WeightEntry]
    @Environment(\.modelContext) private var context
    @State private var newWeight = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Progress").font(.largeTitle).bold()
                if let p = profiles.first {
                    Text("Current weight: \(p.weightKg, specifier: "%.1f") kg · Target: \(p.targetWeightKg, specifier: "%.1f") kg")
                    Text("Workouts completed: \(sessions.filter { $0.isComplete }.count) · Total sessions: \(sessions.count)")
                    let vol = sessions.reduce(0) { $0 + $1.totalVolumeKg }
                    Text("Total training volume: \(Int(vol)) kg (sum of reps x weight across all saved sets — that is how volume is calculated here)")
                    if let best = sessions.flatMap({ $0.sets }).max(by: { $0.weightKg < $1.weightKg }) {
                        Text("Heaviest saved set: \(best.exerciseName) — \(Int(best.weightKg)) kg x \(best.reps) reps")
                    }
                }
                HStack {
                    TextField("New weight (kg)", text: $newWeight).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    Button("Save") {
                        if let v = Double(newWeight) { let w = WeightEntry(); w.weightKg = v; context.insert(w); try? context.save(); newWeight = "" }
                    }
                }
                ForEach(weights.sorted(by: { $0.date > $1.date })) { w in
                    Text("\(w.date, style: .date): \(w.weightKg, specifier: "%.1f") kg")
                }
                Text("Body-fat percentage and muscle growth are NOT inferred from camera images.").font(.caption).foregroundColor(GymTheme.secondaryText)
            }.padding()
        }.background(GymTheme.background)
    }
}
