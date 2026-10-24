import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Photo food logging, in 3 easy steps:
/// 1. Take a photo with the camera, or choose a photo from your library.
/// 2. Tap the food name that matches the photo.
/// 3. Adjust the grams — the app calculates protein, carbs, fat, fibre and
///    calories instantly, and saves them with the photo.
///
/// HONEST LIMIT — READ THIS BEFORE CLAIMING MORE: this screen does NOT
/// automatically identify the food from the photo. iOS has no built-in
/// food recogniser, and no food-AI model or nutrition API key is bundled
/// with this app. Automatic photo recognition would need either a trained
/// food model added to the app, or a nutrition API key — neither is in
/// this build. What IS real here: the photo is saved with the entry, and
/// the macros are calculated exactly from the food and grams YOU confirm.
/// Values are estimates for the stated grams, not laboratory measurements.
struct PhotoFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var allFoods: [FoodEntry]
    @State private var photo: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var query = ""
    @State private var vegOnly = false
    @State private var selected: FoodItem?
    @State private var grams: Double = 100
    @State private var meal = "Breakfast"
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log food by photo").font(.largeTitle).bold()
                    Text("Step 1 — photo. Step 2 — tap the food. Step 3 — adjust grams and save.").foregroundColor(GymTheme.secondaryText)

                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Your food photo").font(.headline)
                            if let photo {
                                Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 220).cornerRadius(12)
                                Button("Change photo") { self.photo = nil }
                            } else {
                                HStack {
                                    Button("📸 Take photo") { showCamera = true }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
                                    PhotosPicker(selection: $pickerItem, matching: .images) { Text("🖼 Choose photo") }.buttonStyle(.borderedProminent).tint(GymTheme.accent)
                                }
                            }
                        }
                    }

                    GymCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("2. Tap the food in your photo").font(.headline)
                            Text("Quick tap — common middle-class foods:").foregroundColor(GymTheme.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(["Cooked rice", "Chapati", "Dal (toor)", "Eggs", "Milk", "Soya chunks", "Curd / yoghurt", "Banana", "Oats", "Peanuts"], id: \.self) { name in
                                        if let item = FoodDatabase.all.first(where: { $0.name == name }) {
                                            Button(name) { selected = item; grams = item.grams }.buttonStyle(.bordered).tint(GymTheme.accent)
                                        }
                                    }
                                }
                            }
                            TextField("Search food (rice, dal, chicken…)", text: $query).textFieldStyle(.roundedBorder)
                            Toggle("Vegetarian only", isOn: $vegOnly)
                            ForEach(FoodDatabase.search(query, vegetarianOnly: vegOnly)) { item in
                                Button {
                                    selected = item; grams = item.grams
                                } label: {
                                    HStack {
                                        Text(item.name).font(.headline)
                                        Spacer()
                                        Text(item.serving).foregroundColor(GymTheme.secondaryText)
                                        if selected?.name == item.name { Text("✓").foregroundColor(GymTheme.accent) }
                                    }
                                }
                            }
                        }
                    }

                    if let item = selected {
                        let scaled = FoodDatabase.scaled(item, grams: grams)
                        GymCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("3. How much did you eat?").font(.headline)
                                Text("\(item.name) — \(Int(grams)) g")
                                Stepper("Grams: \(Int(grams)) g", value: $grams, in: 10...1000, step: 10)
                                HStack {
                                    ForEach([50, 100, 150, 200, 300], id: \.self) { g in
                                        Button("\(g) g") { grams = Double(g) }.buttonStyle(.bordered)
                                    }
                                }
                                Text("Calculated for \(Int(grams)) g:").font(.headline)
                                Text("\(Int(scaled.calories)) kcal · Protein \(scaled.protein, specifier: "%.1f") g · Carbs \(scaled.carbs, specifier: "%.1f") g · Fat \(scaled.fat, specifier: "%.1f") g · Fibre \(scaled.fibre, specifier: "%.1f") g")
                                Picker("Meal", selection: $meal) { ForEach(["Breakfast", "Lunch", "Dinner", "Snacks"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                                Button(saved ? "✓ Saved!" : "Save this food") {
                                    let e = FoodEntry(); e.meal = meal; e.foodName = item.name; e.grams = grams
                                    e.calories = scaled.calories; e.protein = scaled.protein; e.carbs = scaled.carbs; e.fat = scaled.fat; e.fibre = scaled.fibre
                                    e.photoData = photo?.jpegData(compressionQuality: 0.7)
                                    context.insert(e); try? context.save(); saved = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
                                }.buttonStyle(.borderedProminent).tint(GymTheme.accent).disabled(photo == nil)
                                if photo == nil { Text("Take or choose a photo first — this is photo food logging.").foregroundColor(.yellow) }
                            }
                        }
                    } else {
                        Text("Pick a food above to see its protein, carbs and calories.").foregroundColor(GymTheme.secondaryText)
                    }

                    if let item = selected, let p = profiles.first {
                        let scaled = FoodDatabase.scaled(item, grams: grams)
                        let t = NutritionCalculator.calculate(age: p.age, weightKg: p.weightKg, heightCm: p.heightCm, sex: p.sex, activityLevel: p.activityLevel, goal: p.goal)
                        let today = allFoods.filter { Calendar.current.isDateInToday($0.date) }
                        let remProt = max(0, t.protein - (today.reduce(0) { $0 + $1.protein } + scaled.protein))
                        let remCarb = max(0, t.carbs - (today.reduce(0) { $0 + $1.carbs } + scaled.carbs))
                        let remFib = max(0, t.fibre - (today.reduce(0) { $0 + $1.fibre } + scaled.fibre))
                        let remCal = max(0, t.calories - (today.reduce(0) { $0 + $1.calories } + scaled.calories))
                        GymCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("To hit today's goal after this food").font(.headline)
                                if remProt <= 0 && remCarb <= 0 && remFib <= 0 {
                                    Text("🎉 Goal hit for today! You have met your protein, carbs and fibre targets.")
                                } else {
                                    Text("Still needed today: Protein \(Int(remProt)) g · Carbs \(Int(remCarb)) g · Fibre \(Int(remFib)) g · Calories \(Int(remCal)) kcal")
                                    Text("What to eat next — low budget, middle-class kitchen foods:").font(.headline)
                                    if remProt > 0 {
                                        ForEach(FoodDatabase.lowCostFoods.prefix(3)) { food in
                                            Text("\(food.name): about \(Int(FoodDatabase.gramsForProtein(food, proteinTarget: remProt))) g gives \(Int(remProt)) g protein (Low cost)")
                                        }
                                    }
                                    if remCarb > 0, let rice = FoodDatabase.all.first(where: { $0.name == "Cooked rice" }) {
                                        Text("Cooked rice: about \(Int(FoodDatabase.gramsForCarbs(rice, carbTarget: remCarb))) g gives \(Int(remCarb)) g carbs (Low cost)")
                                    }
                                    Text("No expensive supplements needed — dal, soya chunks, eggs, milk, curd, rice and chapati are enough to hit the goal.").foregroundColor(GymTheme.secondaryText)
                                }
                            }
                        }
                    }

                    Text("Photo note: the app does not auto-identify food from the photo yet — you tap the food name, and the app calculates the macros. That keeps the numbers honest instead of guessing from a picture. Automatic recognition would need a food AI model or nutrition API key added in a future version.").font(.caption).foregroundColor(GymTheme.secondaryText)
                }.padding()
            }.background(GymTheme.background)
            .navigationTitle("Photo food")
            .toolbar { Button("Close") { dismiss() } }
            .sheet(isPresented: $showCamera) { CameraPicker(image: $photo) }
            .onChange(of: pickerItem) {
                Task {
                    if let data = try? await pickerItem?.loadTransferable(type: Data.self), let img = UIImage(data: data) { photo = img }
                }
            }
        }
    }
}

/// Camera picker (UIImagePickerController). Falls back to the photo library
/// on devices / simulators with no camera.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
