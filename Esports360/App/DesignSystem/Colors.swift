import SwiftUI

enum E360Color {
    static let background = Color(hex: 0x0d0d0f)
    static let onboardingBackground = Color(hex: 0x080710)
    static let surface = Color(hex: 0x141418)
    static let elevatedSurface = Color(hex: 0x1c1c22)
    static let glass = Color.white.opacity(0.06)
    static let primary = Color(hex: 0x8b5cf6)
    static let primaryGlow = Color(hex: 0x8b5cf6, alpha: 0.15)
    static let accent = Color(hex: 0x10d9a4)
    static let live = Color(hex: 0xff3b30)
    static let gold = Color(hex: 0xf5c542)
    static let neonPurple = Color(hex: 0xd946ef)
    static let neonGreen = Color(hex: 0x10b981)
    static let textPrimary = Color(hex: 0xf5f5f7)
    static let textSecondary = Color(hex: 0x8e8e9a)
    static let textTertiary = Color(hex: 0x444458)
    static let divider = Color.white.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.28)
    
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.15), Color.white.opacity(0.02)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension EsportsGame {
    var themeColor: Color {
        switch self {
        case .leagueOfLegends: return Color(hex: 0xc89b3c) // LoL Gold
        case .counterStrike: return Color(hex: 0xf36c21)   // CS2 Orange
        case .valorant: return Color(hex: 0xff4655)        // Valorant Red
        case .dota2: return Color(hex: 0xe43e2e)           // Dota2 Red
        case .rocketLeague: return Color(hex: 0x0088ff)    // RL Blue
        case .overwatch: return Color(hex: 0xf99e1a)       // OW Orange
        case .rainbowSix: return Color(hex: 0xffd700)      // R6 Yellow
        default: return E360Color.primary                 // Default Violet
        }
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var e360CardGlow: LinearGradient {
        LinearGradient(
            colors: [E360Color.primaryGlow, E360Color.gold.opacity(0.08), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func e360CardGlow(for game: EsportsGame) -> LinearGradient {
        LinearGradient(
            colors: [game.themeColor.opacity(0.18), game.themeColor.opacity(0.04), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

