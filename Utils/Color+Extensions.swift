import SwiftUI

extension Color {
    static let backgroundCream = Color(hex: "FDF9F3")
    static let primaryEspresso = Color(hex: "2C1D14")
    static let secondaryTaupe = Color(hex: "B7A99A")
    static let buttonBrown = Color(hex: "5C4433")
    static let accentWarmNeutral = Color(hex: "896A47")
    static let accentPaleGrey = Color(hex: "EFEFEC")
    static let neutralGray = Color(hex: "6A6A6A")
    static let quoteTextTaupe = Color(hex: "5A4A42")
    static let quoteBubbleBeige = Color(hex: "F4EFEA")
    
    // New colors for this specific design
    static let cloudEllipseBase = Color(hex: "F7F4EF")
    static let quoteTextBrown = Color(hex: "4A3F35")
    static let cloudPuffGray = Color(hex: "D9D9D9")
}

// Helper extension to initialize Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Default to black if invalid hex
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 