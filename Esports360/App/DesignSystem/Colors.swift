import SwiftUI

// MARK: - E360 Design System — iOS 26 Liquid Glass Edition
// Palette calibrated for OLED dark, P3 wide-gamut, Dynamic Island awareness

enum E360Color {
    // ── Backgrounds ──────────────────────────────────────────────
    /// True black OLED base
    static let background         = Color(hex: 0x080810)
    /// Elevated card surface
    static let surface            = Color(hex: 0x111118)
    /// Second-level card (modals, sheets)
    static let elevatedSurface    = Color(hex: 0x18181f)
    /// Third-level chip / input background
    static let tintedSurface      = Color(hex: 0x1e1e28)
    /// Onboarding gradient base
    static let onboardingBackground = Color(hex: 0x06060e)

    // ── Brand ─────────────────────────────────────────────────────
    /// Signature violet
    static let primary            = Color(hex: 0x7c3aed)
    static let primaryBright      = Color(hex: 0xa855f7)
    static let primaryGlow        = Color(hex: 0x7c3aed, alpha: 0.20)
    /// Esports teal
    static let accent             = Color(hex: 0x06d6a0)
    static let accentBright       = Color(hex: 0x34eca4)
    static let accentGlow         = Color(hex: 0x06d6a0, alpha: 0.18)

    // ── Semantic ──────────────────────────────────────────────────
    static let live               = Color(hex: 0xff3b30)
    static let liveGlow           = Color(hex: 0xff3b30, alpha: 0.22)
    static let gold               = Color(hex: 0xfbbf24)
    static let goldGlow           = Color(hex: 0xfbbf24, alpha: 0.18)
    static let success            = Color(hex: 0x22c55e)
    static let warning            = Color(hex: 0xf59e0b)
    static let error              = Color(hex: 0xef4444)

    // ── Neon Accents ─────────────────────────────────────────────
    static let neonPurple         = Color(hex: 0xd946ef)
    static let neonGreen          = Color(hex: 0x10b981)
    static let neonBlue           = Color(hex: 0x3b82f6)
    static let neonOrange         = Color(hex: 0xf97316)

    // ── Text ──────────────────────────────────────────────────────
    static let textPrimary        = Color(hex: 0xf8f8fc)
    static let textSecondary      = Color(hex: 0x9090a0)
    static let textTertiary       = Color(hex: 0x50505e)
    static let textDisabled       = Color(hex: 0x383845)

    // ── Lines & Borders ───────────────────────────────────────────
    static let divider            = Color.white.opacity(0.07)
    static let dividerStrong      = Color.white.opacity(0.13)
    static let cardShadow         = Color.black.opacity(0.40)

    // ── Glass ─────────────────────────────────────────────────────
    static let glassFill          = Color.white.opacity(0.05)
    static let glassBorder = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let glass = Color.white.opacity(0.05)
}

// MARK: - Color Hex Init
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8)  & 0xff) / 255,
            blue:  Double( hex        & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Game Theme Colors (iOS 26 vibrant palette)
extension EsportsGame {
    var themeColor: Color {
        switch self {
        case .leagueOfLegends: return Color(hex: 0xc89b3c)   // LoL gold
        case .counterStrike:   return Color(hex: 0xff6b35)   // CS2 orange
        case .valorant:        return Color(hex: 0xff4655)   // Valorant red
        case .dota2:           return Color(hex: 0xe84560)   // Dota2 crimson
        case .rocketLeague:    return Color(hex: 0x0ea5e9)   // RL sky blue
        case .overwatch:       return Color(hex: 0xf97316)   // OW orange
        case .rainbowSix:      return Color(hex: 0xeab308)   // R6 yellow
        default:               return E360Color.primary
        }
    }
    var themeGradient: LinearGradient {
        LinearGradient(
            colors: [themeColor, themeColor.opacity(0.5)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - ShapeStyle Convenience
extension ShapeStyle where Self == LinearGradient {
    static var e360CardGlow: LinearGradient {
        LinearGradient(
            colors: [E360Color.primaryGlow, E360Color.goldGlow, .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static func e360CardGlow(for game: EsportsGame) -> LinearGradient {
        LinearGradient(
            colors: [game.themeColor.opacity(0.22), game.themeColor.opacity(0.05), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static var e360HeroGradient: LinearGradient {
        LinearGradient(
            colors: [E360Color.primary.opacity(0.35), E360Color.accent.opacity(0.18), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
