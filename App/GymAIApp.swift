import SwiftUI
import SwiftData

@main
struct GymAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [UserProfile.self, WorkoutSessionRecord.self, SetRecord.self, FoodEntry.self, WeightEntry.self, WaterEntry.self])
        }
    }
}
