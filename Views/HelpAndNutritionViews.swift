import SwiftUI
import SwiftData

/// Personal nutrition from YOUR weight and height (from onboarding), with
/// low-price foods to meet protein, carbs and fibre.
/// Targets use the same Mifflin-St Jeor maths as the rest of the app.
/// Cost tiers are approximate, not exact rupee prices — prices vary by city.
struct LowPriceNutritionView: View {
    @Query private var profiles: [UserProfile]
    @Query private var foods: [FoodEntry]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Low-price nutrition for you").font(.largeTitle).bold()
                if let p = profiles.first {
                    let t = NutritionCalculator.calculate(age: p.age, weightKg: p.weightKg, heightCm: p.heightCm, sex: p.sex, activityLevel: p.activityLevel, goal: p.goal)
                    let today = foods.filter { Calendar.current.isDateInToday($0.date) }
                    let prot = today.reduce(0) { $0 + $1.protein }
                    let carb = today.reduce(0) { $0 + $1.carbs }
                    let fib = today.reduce(0) { $0 + $1.fibre }
                    GymCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Based on your weight \(p.weightKg, specifier: "%.0f") kg and height \(p.heightCm, specifier: "%.0f") cm").font(.headline)
                            Text("Goal: \(p.goal) · Activity: \(p.activityLevel)")
                            Text("You need each day: Protein \(Int(t.protein)) g · Carbs \(Int(t.carbs)) g · Fibre \(Int(t.fibre)) g · Calories \(Int(t.calories)) kcal")
                            Text("Still needed today: Protein \(Int(max(0, t.protein - prot))) g · Carbs \(Int(max(0, t.carbs - carb))) g · Fibre \(Int(max(0, t.fibre - fib))) g")
                            Text(t.assumption).font(.caption).foregroundColor(GymTheme.secondaryText)
                        }
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cheap ways to fill your remaining protein").font(.headline)
                            let remaining = max(0, t.protein - prot)
                            if remaining <= 0 {
                                Text("You have already met today's protein target. Well done.")
                            } else {
                                ForEach(FoodDatabase.lowCostFoods.prefix(6)) { item in
                                    let grams = FoodDatabase.gramsForProtein(item, proteinTarget: remaining)
                                    Text("\(item.name): about \(Int(grams)) g gives \(Int(remaining)) g protein (Low cost)")
                                }
                                Text("Example cheap protein day: soya chunks, dal, eggs, milk and curd — all Low cost above.").foregroundColor(GymTheme.secondaryText)
                            }
                        }
                    }
                    GymCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Low-price foods (all Low cost)").font(.headline)
                            ForEach(FoodDatabase.lowCostFoods) { item in
                                Text("\(item.name) — \(item.serving): \(Int(item.calories)) kcal, \(item.protein, specifier: "%.0f") g protein, \(item.carbs, specifier: "%.0f") g carbs, \(item.fibre, specifier: "%.0f") g fibre")
                            }
                            Text("Prices are not shown in rupees because they change by city and shop. 'Low' means cheapest everyday foods, not an exact price.").font(.caption).foregroundColor(GymTheme.secondaryText)
                        }
                    }
                } else {
                    Text("Complete onboarding first (weight and height), then this screen will show your personal targets.")
                }
            }.padding()
        }.background(GymTheme.background)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    var isUser: Bool
}

/// Help Chat: raise a complaint about the app, get fix steps right away,
/// and mark it Solved or Still not solved. Solved = workaround worked.
/// Still not solved = Escalated, with a summary to fix in the next app version.
/// Honest limit: an installed app cannot rewrite its own code, so a real bug
/// fix always needs a new IPA version — that is what Escalated means.
struct HelpChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HelpComplaint.date, order: .reverse) private var complaints: [HelpComplaint]
    @State private var messages: [ChatMessage] = [ChatMessage(text: "Hi! Tell me what problem you have with the app, in your own words. I will give you fix steps right away.", isUser: false)]
    @State private var input = ""
    @State private var lastComplaint: HelpComplaint?

    var body: some View {
        VStack(spacing: 12) {
            Text("Help Chat").font(.largeTitle).bold()
            Text("Raise a complaint here. I will try to fix it with steps now. If it still does not work, it will be marked for the next app update.").font(.caption).foregroundColor(GymTheme.secondaryText).multilineTextAlignment(.center)
            // Quick topics: one tap asks a relevant question, so the answer
            // is about that problem — not an unrelated one.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(["Camera not counting reps", "Voice not speaking", "Food protein target wrong", "Workout day wrong", "App crashes on open", "Reminder not coming"], id: \.self) { topic in
                        Button(topic) { sendText(topic) }.buttonStyle(.bordered).tint(GymTheme.accent)
                    }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { m in
                        HStack {
                            if m.isUser { Spacer() }
                            Text(m.text).padding().background(m.isUser ? GymTheme.accent : GymTheme.card).foregroundColor(m.isUser ? .black : .white).cornerRadius(12)
                            if !m.isUser { Spacer() }
                        }
                    }
                }
            }
            if let c = lastComplaint, c.status == "Open" {
                HStack {
                    Button("✓ This solved it") { c.status = "Solved"; try? context.save(); messages.append(ChatMessage(text: "Great! Marked as Solved.", isUser: false)); lastComplaint = nil }
                    Button("Still not solved") { c.status = "Escalated"; try? context.save(); messages.append(ChatMessage(text: "Recorded as Escalated. This needs a fix in the next app version — share this complaint with the developer so it can be fixed and a new ios.ipa built.", isUser: false)); lastComplaint = nil }
                }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
            }
            HStack {
                TextField("Describe the problem…", text: $input).textFieldStyle(.roundedBorder)
                Button("Send") { send() }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
            }
            if !complaints.isEmpty {
                Text("Your past complaints").font(.headline)
                ForEach(complaints.prefix(5)) { c in
                    GymCard { VStack(alignment: .leading, spacing: 4) { Text(c.message).font(.headline); Text("Status: \(c.status) · \(c.date, style: .date)") } }
                }
            }
            Spacer()
        }.padding().background(GymTheme.background)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        sendText(text)
    }

    private func sendText(_ text: String) {
        messages.append(ChatMessage(text: text, isUser: true))
        let solution = HelpAssistant.solution(for: text)
        let c = HelpComplaint(); c.message = text; c.solutionGiven = solution; c.status = "Open"
        context.insert(c); try? context.save(); lastComplaint = c
        messages.append(ChatMessage(text: solution, isUser: false))
        messages.append(ChatMessage(text: "Did that solve it? Tap a button above.", isUser: false))
        input = ""
    }
}
