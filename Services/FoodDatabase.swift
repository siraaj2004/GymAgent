import Foundation

/// Indian food database. Values are per the stated typical serving, not laboratory
/// measurements, and the UI says so. Photo/voice suggestions are suggestions only:
/// the user always confirms or corrects food and quantity before saving.
/// No price is shown: no reliable local price data is bundled.
struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var serving: String
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
    var isVegetarian: Bool
    /// Cost tier is RELATIVE and approximate (typical Indian grocery prices,
    /// varies by city and shop). No exact rupee price is claimed, because
    /// prices change and were not verified for the user's market.
    /// "Low" = cheapest everyday protein/fibre sources.
    var costTier: String = "Medium"
}

enum FoodDatabase {
    static let all: [FoodItem] = [
        FoodItem(name: "Cooked rice", serving: "1 cup (150 g)", grams: 150, calories: 195, protein: 3.6, carbs: 42, fat: 0.5, fibre: 0.8, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Chapati", serving: "1 medium (40 g)", grams: 40, calories: 120, protein: 3.5, carbs: 22, fat: 1.5, fibre: 2.5, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Chicken breast", serving: "100 g cooked", grams: 100, calories: 165, protein: 31, carbs: 0, fat: 3.6, fibre: 0, isVegetarian: false, costTier: "Medium"),
        FoodItem(name: "Eggs", serving: "2 large", grams: 100, calories: 140, protein: 12, carbs: 1, fat: 9, fibre: 0, isVegetarian: false, costTier: "Low"),
        FoodItem(name: "Paneer", serving: "100 g", grams: 100, calories: 265, protein: 18, carbs: 3, fat: 20, fibre: 0, isVegetarian: true, costTier: "Medium"),
        FoodItem(name: "Milk", serving: "1 glass (250 ml)", grams: 250, calories: 150, protein: 8, carbs: 12, fat: 8, fibre: 0, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Dal (toor)", serving: "1 cup cooked (200 g)", grams: 200, calories: 200, protein: 12, carbs: 32, fat: 2, fibre: 8, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Oats", serving: "1 bowl (40 g dry)", grams: 40, calories: 150, protein: 5, carbs: 27, fat: 3, fibre: 4, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Banana", serving: "1 medium (120 g)", grams: 120, calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fibre: 3, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Idli", serving: "2 pieces (100 g)", grams: 100, calories: 120, protein: 3, carbs: 25, fat: 0.5, fibre: 1.5, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Dosa", serving: "1 plain (100 g)", grams: 100, calories: 170, protein: 3.5, carbs: 32, fat: 3, fibre: 2, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Chicken biryani", serving: "1 plate (300 g)", grams: 300, calories: 480, protein: 28, carbs: 55, fat: 15, fibre: 3, isVegetarian: false, costTier: "Medium"),
        FoodItem(name: "Soya chunks", serving: "50 g dry", grams: 50, calories: 170, protein: 26, carbs: 16, fat: 0.5, fibre: 6, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Curd / yoghurt", serving: "1 cup (200 g)", grams: 200, calories: 120, protein: 7, carbs: 9, fat: 6, fibre: 0, isVegetarian: true, costTier: "Low"),
        FoodItem(name: "Peanuts", serving: "1 small handful (30 g)", grams: 30, calories: 170, protein: 7, carbs: 5, fat: 14, fibre: 2.5, isVegetarian: true, costTier: "Low"),
    ]

    static func search(_ query: String, vegetarianOnly: Bool) -> [FoodItem] {
        let q = query.lowercased()
        return all.filter { item in
            (!vegetarianOnly || item.isVegetarian) && (q.isEmpty || item.name.lowercased().contains(q))
        }
    }

    /// Scaled to the grams the user enters. This is what FoodView saves.
    static func scaled(_ item: FoodItem, grams: Double) -> FoodItem {
        let f = grams / item.grams
        return FoodItem(name: item.name, serving: "\(Int(grams)) g", grams: grams,
                        calories: (item.calories * f).rounded(), protein: (item.protein * f * 10).rounded() / 10,
                        carbs: (item.carbs * f * 10).rounded() / 10, fat: (item.fat * f * 10).rounded() / 10,
                        fibre: (item.fibre * f * 10).rounded() / 10, isVegetarian: item.isVegetarian, costTier: item.costTier)
    }

    /// Simple remaining-target suggestions: highest-protein foods first when protein is short,
    /// otherwise foods that fit the remaining calories. No medical claims.
    static func suggestions(remainingProtein: Double, remainingCalories: Double, vegetarianOnly: Bool) -> [FoodItem] {
        let pool = all.filter { !vegetarianOnly || $0.isVegetarian }
        if remainingProtein > 20 { return pool.sorted { $0.protein > $1.protein }.prefix(5).map { $0 } }
        return pool.filter { $0.calories <= max(100, remainingCalories) }.prefix(5).map { $0 }
    }

    /// Low-price foods only, highest protein first. Use these to fill remaining
    /// protein / fibre cheaply. Cost tiers are approximate, not exact prices.
    static var lowCostFoods: [FoodItem] {
        all.filter { $0.costTier == "Low" }.sorted { $0.protein > $1.protein }
    }

    /// Grams of a food needed to get a target amount of protein, from its
    /// per-serving protein. Example: if a food has 26 g protein per 50 g,
    /// getting 50 g protein needs about 96 g of it.
    static func gramsForProtein(_ item: FoodItem, proteinTarget: Double) -> Double {
        guard item.protein > 0 else { return 0 }
        return (proteinTarget / item.protein * item.grams).rounded()
    }

    /// Grams of a food needed to get a target amount of carbs, same idea as protein.
    static func gramsForCarbs(_ item: FoodItem, carbTarget: Double) -> Double {
        guard item.carbs > 0 else { return 0 }
        return (carbTarget / item.carbs * item.grams).rounded()
    }
}
