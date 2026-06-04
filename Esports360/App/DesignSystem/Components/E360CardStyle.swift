import SwiftUI

struct E360CardBackground: ViewModifier {
    var isHighlighted = false
    var cornerRadius: CGFloat = 16
    var borderColor: Color? = nil
    var game: EsportsGame? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(E360Color.surface)

                    if isHighlighted {
                        if let game {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(LinearGradient.e360CardGlow(for: game))
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.e360CardGlow)
                        }
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor ?? E360Color.divider, lineWidth: 1)
            )
            .shadow(color: E360Color.cardShadow, radius: isHighlighted ? 18 : 8, y: isHighlighted ? 10 : 4)
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.triggerImpact(style: .light)
                }
            }
    }
}


struct E360GlassCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isHighlighted = false
    var game: EsportsGame? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    if isHighlighted {
                        if let game {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(LinearGradient.e360CardGlow(for: game))
                        } else {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.e360CardGlow)
                        }
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(E360Color.glassBorder, lineWidth: 1)
            )
            .shadow(color: E360Color.cardShadow, radius: isHighlighted ? 18 : 8, y: isHighlighted ? 8 : 4)
    }
}

extension View {
    func e360Card(
        highlighted: Bool = false,
        cornerRadius: CGFloat = 16,
        borderColor: Color? = nil,
        game: EsportsGame? = nil
    ) -> some View {
        modifier(E360CardBackground(isHighlighted: highlighted, cornerRadius: cornerRadius, borderColor: borderColor, game: game))
    }

    func e360GlassCard(
        cornerRadius: CGFloat = 16,
        highlighted: Bool = false,
        game: EsportsGame? = nil
    ) -> some View {
        modifier(E360GlassCardBackground(cornerRadius: cornerRadius, isHighlighted: highlighted, game: game))
    }
}

