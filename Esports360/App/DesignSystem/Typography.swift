import SwiftUI

enum E360Font {
    // Thmanyah Sans – PostScript names (from the official Thmanyah font v1.2)
    private static let thmanyahRegular = "Thmanyahsans12-Regular"
    private static let thmanyahMedium  = "Thmanyahsans12-Medium"
    private static let thmanyahBold    = "Thmanyahsans12-Bold"
    private static let thmanyahBlack   = "thmanyahsans-Black"

    /// Resolves the correct PostScript font name for a given weight.
    private static func thmanyah(_ size: CGFloat, weight: Font.Weight) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:
            name = thmanyahBlack
        case .bold, .semibold:
            name = thmanyahBold
        case .medium:
            name = thmanyahMedium
        default:
            name = thmanyahRegular
        }
        return .custom(name, size: size)
    }

    // MARK: - Public API

    /// Display / headline font — Thmanyah for both Arabic and English.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        thmanyah(size, weight: weight)
    }

    /// Extra-large hero text for onboarding or splash screens.
    static func hero(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        thmanyah(size, weight: weight)
    }

    /// Body / paragraph text.
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        thmanyah(size, weight: weight)
    }

    /// Explicit Arabic font — same as body since Thmanyah supports Arabic natively.
    static func arabic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        thmanyah(size, weight: weight)
    }

    /// Numeric / score text — system rounded for tabular figures.
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Monospace for codes, tags, chips.
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}


// MARK: - View Modifiers

struct E360ScreenTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(E360Font.display(28, weight: .black))
            .foregroundStyle(E360Color.textPrimary)
    }
}

extension View {
    func e360ScreenTitle() -> some View {
        modifier(E360ScreenTitle())
    }
}
