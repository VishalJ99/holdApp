import SwiftUI

enum UIConstants {
    // Colors
    static let primaryBlue = Color(hex: "#007AFF")
    static let successGreen = Color(hex: "#34C759")
    static let warningOrange = Color(hex: "#FF9500")
    static let errorRed = Color(hex: "#FF3B30")

    static let lightGray = Color(hex: "#F5F5F5")
    static let mediumGray = Color(hex: "#E5E5E5")
    static let darkGray = Color(hex: "#D1D1D6")
    static let systemGray = Color(hex: "#8E8E93")

    // Typography
    static let spotlightFontSize: CGFloat = 18
    static let editorFontSize: CGFloat = 14
    static let toastFontSize: CGFloat = 12

    // Spacing
    static let spotlightPadding: CGFloat = 16
    static let editorTaskRowHeight: CGFloat = 32
    static let hierarchyIndentation: CGFloat = 20

    // Dimensions
    static let spotlightWidth: CGFloat = 600
    static let spotlightHeight: CGFloat = 60
    static let spotlightBorderRadius: CGFloat = 10

    // Animations
    static let toastFadeIn: Double = 0.2
    static let toastHold: Double = 0.8
    static let toastFadeOut: Double = 0.2

    static let stateTransition: Double = 0.2
}

// Helper for hex colors
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
            (a, r, g, b) = (255, 0, 0, 0)
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
