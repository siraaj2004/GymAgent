import SwiftUI

enum GymTheme {
    static let background = Color(hex: "0B0F19")
    static let card = Color(hex: "151C2C")
    static let accent = Color(hex: "00E5A8")
    static let secondaryText = Color(hex: "9CA3AF")
}

extension Color {
    init(hex: String) {
        let v = Int(hex, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}

struct GymCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding().background(GymTheme.card).cornerRadius(16)
    }
}

struct ProgressBar: View {
    var value: Double; var total: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(GymTheme.accent).frame(width: geo.size.width * CGFloat(min(1, total > 0 ? value / total : 0)))
            }
        }.frame(height: 8)
    }
}
