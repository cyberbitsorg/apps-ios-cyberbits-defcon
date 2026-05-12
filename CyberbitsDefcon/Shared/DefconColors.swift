import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    static func defcon(_ level: Int) -> Color {
        switch level {
        case 1: return Color(hex: "22c55e")
        case 2: return Color(hex: "3b82f6")
        case 3: return Color(hex: "f59e0b")
        case 4: return Color(hex: "ea580c")
        case 5: return Color(hex: "dc2626")
        default: return .gray
        }
    }

    static let defconBackground = Color(hex: "0f0f1a")
    static let defconSurface = Color(hex: "1a1a2e")
    static let defconBorder = Color(hex: "2a2a3e")

    init(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.count == 6 { h = "FF" + h }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
extension Color {
    static var adaptiveBackground: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color.defconBackground) : .systemBackground })
    }
    static var adaptiveSurface: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color.defconSurface) : UIColor.secondarySystemBackground })
    }
    static var adaptiveBorder: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color.defconBorder) : UIColor.separator })
    }
}
#endif
