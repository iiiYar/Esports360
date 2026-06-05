import SwiftUI

// MARK: - GlassKit — iOS 26 Liquid Glass design language
// Provides reusable modifiers, shapes, and material layers
// that replicate the iOS 26 frosted-glass system aesthetic.

// MARK: - Glass Card Modifier
struct E360GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: Double
    var shadowRadius: CGFloat
    var tintColor: Color

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(E360Color.surface)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.4))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [tintColor.opacity(0.07), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [Color.white.opacity(borderOpacity), Color.white.opacity(borderOpacity * 0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1.0)
            }
            .shadow(color: E360Color.cardShadow, radius: shadowRadius, y: shadowRadius * 0.5)
    }
}

extension View {
    func e360GlassCard(
        cornerRadius: CGFloat = 20,
        borderOpacity: Double = 0.14,
        shadowRadius: CGFloat = 12,
        tintColor: Color = E360Color.primary
    ) -> some View {
        modifier(E360GlassCardModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            shadowRadius: shadowRadius,
            tintColor: tintColor
        ))
    }

    func e360GlassCard(game: EsportsGame, cornerRadius: CGFloat = 20) -> some View {
        modifier(E360GlassCardModifier(
            cornerRadius: cornerRadius,
            borderOpacity: 0.18,
            shadowRadius: 14,
            tintColor: game.themeColor
        ))
    }
}

// MARK: - Floating Island Glow
struct E360IslandGlow: View {
    var color: Color = E360Color.primary
    var intensity: Double = 1.0

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.22 * intensity))
            .frame(width: 180, height: 40)
            .blur(radius: 30)
            .allowsHitTesting(false)
    }
}

// MARK: - Ambient Background Glow
struct E360AmbientGlow: View {
    var colors: [Color] = [E360Color.primary.opacity(0.10), E360Color.accent.opacity(0.05), .clear]
    var height: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                .frame(height: height)
                .blur(radius: 25)
                .allowsHitTesting(false)
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Live Pulse Effect
struct E360LivePulse: View {
    @State private var pulsing = false
    var color: Color = E360Color.live
    var size: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2.2, height: size * 2.2)
                .scaleEffect(pulsing ? 1.5 : 0.7)
                .opacity(pulsing ? 0 : 0.8)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Score Separator
struct E360VsSeparator: View {
    var body: some View {
        Text("VS")
            .font(E360Font.mono(11, weight: .black))
            .foregroundStyle(E360Color.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(E360Color.tintedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - E360 Badge
struct E360Badge: View {
    let text: String
    var color: Color = E360Color.accent
    var size: CGFloat = 9

    var body: some View {
        Text(text)
            .font(E360Font.mono(size, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - Section Header
struct E360SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var badge: String? = nil
    var badgeColor: Color = E360Color.accent
    var action: (() -> Void)? = nil
    var actionLabel: LocalizedStringKey = "common.seeAll"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(E360Font.display(20, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                    if let badge {
                        E360Badge(text: badge, color: badgeColor)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(E360Font.body(12, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(E360Font.body(13, weight: .bold))
                        .foregroundStyle(E360Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Press Scale Effect
struct E360PressScale: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shimmer
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.06),
                        Color.white.opacity(0)
                    ],
                    startPoint: UnitPoint(x: phase, y: 0),
                    endPoint: UnitPoint(x: phase + 0.5, y: 1)
                )
                .blendMode(.screen)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
            .allowsHitTesting(false)
    }
}
extension View {
    func e360Shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Skeleton Row
struct SkeletonRow: View {
    var width: CGFloat? = nil
    var height: CGFloat = 90
    var cornerRadius: CGFloat = 18
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(E360Color.surface)
            .frame(width: width, height: height)
            .e360Shimmer()
    }
}
