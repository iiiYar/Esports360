import SwiftUI

// MARK: - E360 Typography — iOS 26 Dynamic Type aware
// Uses SF Pro Display for headings, SF Mono for data/scores,
// and system rounded for UI labels.

enum E360Font {
    /// Large display text — titles, hero numbers
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// Body copy — descriptions, labels
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// Monospaced — scores, timers, codes
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Numbers — stats, counters  
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
            .monospacedDigit()
    }
    /// Rounded — pill labels, badges
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - iOS 26 Text Style Tokens
extension View {
    /// Hero headline — 34pt black
    func e360Hero() -> some View {
        self.font(E360Font.display(34, weight: .black))
            .foregroundStyle(E360Color.textPrimary)
    }
    /// Section title — 22pt bold
    func e360Title() -> some View {
        self.font(E360Font.display(22, weight: .bold))
            .foregroundStyle(E360Color.textPrimary)
    }
    /// Card title — 17pt semibold
    func e360CardTitle() -> some View {
        self.font(E360Font.body(17, weight: .semibold))
            .foregroundStyle(E360Color.textPrimary)
    }
    /// Caption — 11pt medium
    func e360Caption() -> some View {
        self.font(E360Font.body(11, weight: .medium))
            .foregroundStyle(E360Color.textSecondary)
    }
    /// Score / stat number — mono bold
    func e360Score(_ size: CGFloat = 28) -> some View {
        self.font(E360Font.number(size, weight: .black))
            .foregroundStyle(E360Color.textPrimary)
    }
}
