import SwiftUI

/// Daily food items (changing every day) + Guntur / Hyderabad prices.
///
/// WHAT THIS IS: a 7-day rotation — Monday's foods are different from
/// Tuesday's, and so on — using only low-cost, middle-class foods, with
/// macros calculated from FoodDatabase for each day. Pick your city:
/// Guntur or Hyderabad.
///
/// PRICES — HONEST SOURCE NOTE, DO NOT PRESENT AS LIVE MANDI RATES:
/// Only 3 prices below are from a web source checked on 24 Oct 2026, and
/// they are shown with their source and date in the app. All other foods
/// show "price not verified — check your local shop" instead of a guessed
/// number, because shop prices change daily and by brand.
/// - Eggs, Hyderabad: NECC ₹5.7 per egg, ₹68.4 per dozen, 24 Oct 2026, wholesale
///   (retail in a shop is usually a little higher).
/// - Chicken, Hyderabad: local market skinless / boneless about ₹220-225 per kg,
///   24 Oct 2026 (other listings that day ranged ₹170 live to ₹280 cleaned —
///   shop price varies a lot, so check your shop).
/// - Toor dal, Hyderabad: listings ₹105-125 per kg for common brands,
///   24 Oct 2026, premium brands up to ₹165-175 per kg.
/// Guntur: no separate verified Guntur mandi list was found, so Guntur
/// uses the same nearby Andhra / Telangana market reference, with a clear
/// note to check your Guntur shop — Guntur prices are usually close to
/// Vijayawada / Hyderabad for eggs and dal, but are NOT claimed identical.
struct MarketPrice: Identifiable {
    let id = UUID()
    var foodName: String
    var unit: String
    var indicativePrice: Double
    var rangeText: String
    var source: String
}

struct DailyMeal: Identifiable {
    let id = UUID()
    var day: String
    var items: [(String, Double)] // food name, grams
}

enum DailyFoodPrices {
    static let prices: [MarketPrice] = [
        MarketPrice(foodName: "Eggs", unit: "per egg", indicativePrice: 5.7, rangeText: "₹5.7 wholesale, ₹68.4 per dozen — retail usually a little higher", source: "NECC Hyderabad, 24 Oct 2026"),
        MarketPrice(foodName: "Chicken breast", unit: "per kg", indicativePrice: 220, rangeText: "About ₹220-225 per kg skinless / boneless — other shops that day: ₹170 live to ₹280 cleaned", source: "Hyderabad local market, 24 Oct 2026"),
        MarketPrice(foodName: "Dal (toor)", unit: "per kg (dry)", indicativePrice: 115, rangeText: "About ₹105-125 per kg common brands, premium up to ₹165-175", source: "Hyderabad listings, 24 Oct 2026"),
    ]

    static let plans: [DailyMeal] = [
        DailyMeal(day: "Monday", items: [("Oats", 40), ("Milk", 250), ("Banana", 120), ("Cooked rice", 150), ("Dal (toor)", 200), ("Curd / yoghurt", 200), ("Peanuts", 30), ("Chapati", 80), ("Eggs", 100)]),
        DailyMeal(day: "Tuesday", items: [("Idli", 100), ("Curd / yoghurt", 200), ("Cooked rice", 150), ("Soya chunks", 50), ("Dal (toor)", 200), ("Banana", 120), ("Chapati", 80), ("Chicken breast", 100)]),
        DailyMeal(day: "Wednesday", items: [("Dosa", 100), ("Curd / yoghurt", 200), ("Cooked rice", 150), ("Dal (toor)", 200), ("Peanuts", 30), ("Milk", 250), ("Chapati", 80), ("Paneer", 100)]),
        DailyMeal(day: "Thursday", items: [("Oats", 40), ("Eggs", 100), ("Chapati", 80), ("Dal (toor)", 200), ("Soya chunks", 50), ("Banana", 120), ("Peanuts", 30), ("Cooked rice", 150), ("Curd / yoghurt", 200), ("Eggs", 100)]),
        DailyMeal(day: "Friday", items: [("Idli", 100), ("Milk", 250), ("Chicken biryani", 300), ("Curd / yoghurt", 200), ("Chapati", 80), ("Dal (toor)", 200)]),
        DailyMeal(day: "Saturday", items: [("Dosa", 100), ("Eggs", 100), ("Cooked rice", 150), ("Dal (toor)", 200), ("Soya chunks", 50), ("Peanuts", 30), ("Chapati", 80), ("Milk", 250), ("Banana", 120)]),
        DailyMeal(day: "Sunday", items: [("Oats", 40), ("Banana", 120), ("Milk", 250), ("Cooked rice", 150), ("Dal (toor)", 200), ("Chicken breast", 100), ("Curd / yoghurt", 200), ("Chapati", 80), ("Eggs", 100), ("Soya chunks", 50)]),
    ]

    static func plan(for date: Date) -> DailyMeal {
        // Sunday = 1 in Calendar, so Monday plan is index 0.
        let weekday = Calendar.current.component(.weekday, from: date)
        let index = (weekday + 5) % 7
        return plans[index]
    }

    static func totals(for plan: DailyMeal) -> (calories: Double, protein: Double, carbs: Double, fibre: Double) {
        var cal = 0.0, prot = 0.0, carb = 0.0, fib = 0.0
        for (name, grams) in plan.items {
            if let item = FoodDatabase.all.first(where: { $0.name == name }) {
                let s = FoodDatabase.scaled(item, grams: grams)
                cal += s.calories; prot += s.protein; carb += s.carbs; fib += s.fibre
            }
        }
        return (cal, prot, carb, fib)
    }
}

struct DailyFoodPricesView: View {
    @State private var city = "Hyderabad"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily food & prices").font(.largeTitle).bold()
                Text("Food items change every day — this is today's plan. Prices are for Guntur / Hyderabad, with sources below.").foregroundColor(GymTheme.secondaryText)
                Picker("City", selection: $city) { ForEach(["Hyderabad", "Guntur"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                if city == "Guntur" {
                    Text("Guntur note: no separate verified Guntur mandi price list was found, so Guntur uses the nearby Andhra / Telangana market reference. Prices in your Guntur shop may differ by a few rupees — check your shop.").font(.caption).foregroundColor(.yellow)
                }
                let today = DailyFoodPrices.plan(for: Date())
                let totals = DailyFoodPrices.totals(for: today)
                GymCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today: \(today.day) — \(city)").font(.headline)
                        ForEach(today.items, id: \.0) { name, grams in
                            Text("\(name) — \(Int(grams)) g")
                        }
                        Text("Day total (estimated): \(Int(totals.calories)) kcal · Protein \(totals.protein, specifier: "%.0f") g · Carbs \(totals.carbs, specifier: "%.0f") g · Fibre \(totals.fibre, specifier: "%.0f") g").font(.headline)
                        Text("This is a low-budget middle-class day plan. Compare it with your personal target in Low-price nutrition — your target depends on your weight and height.").foregroundColor(GymTheme.secondaryText)
                    }
                }
                GymCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other days — food changes daily").font(.headline)
                        ForEach(DailyFoodPrices.plans) { plan in
                            let t = DailyFoodPrices.totals(for: plan)
                            Text("\(plan.day): \(plan.items.map { $0.0 }.joined(separator: ", ")) — \(Int(t.calories)) kcal, \(t.protein, specifier: "%.0f") g protein")
                        }
                    }
                }
                GymCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prices in \(city) — checked 24 Oct 2026").font(.headline)
                        ForEach(DailyFoodPrices.prices) { p in
                            VStack(alignment: .leading) {
                                Text("\(p.foodName) — about ₹\(Int(p.indicativePrice)) \(p.unit)").font(.headline)
                                Text(p.rangeText)
                                Text("Source: \(p.source)").font(.caption).foregroundColor(GymTheme.secondaryText)
                            }
                        }
                        Text("All other foods (rice, chapati, milk, curd, soya, oats, banana, peanuts, paneer): price NOT verified here — do not trust a guessed number. Check your local Guntur / Hyderabad shop, and use the Low cost tier in the app as a guide: dal, soya, eggs, milk and curd are usually cheapest protein. Prices change daily.").font(.caption).foregroundColor(GymTheme.secondaryText)
                    }
                }
            }.padding()
        }.background(GymTheme.background)
    }
}
