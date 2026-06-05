import SwiftUI

// MARK: - GlassKit — iOS 26 Liquid Glass design language  [Phase-2 updated]
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
            Circle().fill(color).frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulsing = true }
        }
    }
}

// MARK: - Score Separator
struct E360VsSeparator: View {
    var body: some View {
        Text("VS")
            .font(E360Font.mono(11, weight: .black))
            .foregroundStyle(E360Color.textTertiary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(E360Color.tintedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - E360Badge
struct E360Badge: View {
    let text: String
    var color: Color = E360Color.accent
    var size: CGFloat = 9
    var body: some View {
        Text(text)
            .font(E360Font.mono(size, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
    }
}

// MARK: - E360SectionHeader v2 (Phase-2)
struct E360SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var badge: String?               = nil
    var badgeColor: Color            = E360Color.accent
    var icon: String?                = nil
    var iconColor: Color             = E360Color.accent
    var action: (() -> Void)?        = nil
    var actionLabel: LocalizedStringKey = "common.seeAll"
    var liveCount: Int?              = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Optional left icon
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(E360Font.display(20, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)

                    if let badge {
                        E360Badge(text: badge, color: badgeColor)
                    }

                    // Live count pill
                    if let live = liveCount, live > 0 {
                        HStack(spacing: 4) {
                            E360LivePulse(color: E360Color.live, size: 5)
                            Text("\(live)")
                                .font(E360Font.mono(10, weight: .black))
                                .foregroundStyle(E360Color.live)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(E360Color.live.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(E360Color.live.opacity(0.22), lineWidth: 1))
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
                    HStack(spacing: 4) {
                        Text(actionLabel)
                            .font(E360Font.body(13, weight: .bold))
                            .foregroundStyle(E360Color.accent)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(E360Color.accent.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - E360PressScale
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
                    colors: [.white.opacity(0), .white.opacity(0.06), .white.opacity(0)],
                    startPoint: UnitPoint(x: phase, y: 0),
                    endPoint: UnitPoint(x: phase + 0.5, y: 1)
                )
                .blendMode(.screen)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.5 }
            }
            .allowsHitTesting(false)
    }
}
extension View {
    func e360Shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - SkeletonRow (legacy compat)
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

// MARK: - E360Divider
struct E360Divider: View {
    var color: Color = E360Color.divider
    var leadingPadding: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .padding(.leading, leadingPadding)
    }
}

// MARK: - Tappable row highlight
struct E360RowHighlight: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .background(pressed ? E360Color.tintedSurface.opacity(0.7) : .clear)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded   { _ in pressed = false }
            )
    }
}
extension View {
    func e360RowHighlight() -> some View { modifier(E360RowHighlight()) }
}
