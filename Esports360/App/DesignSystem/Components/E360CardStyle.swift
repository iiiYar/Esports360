import SwiftUI

// MARK: - E360 Card Style Tokens — iOS 26 refresh

/// Floating pill card for match rows
struct E360MatchRowCard: ViewModifier {
    var themeColor: Color = E360Color.primary
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(E360Color.surface)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [themeColor.opacity(0.09), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [themeColor.opacity(0.28), E360Color.divider],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1)
            }
            .shadow(color: themeColor.opacity(0.10), radius: 12, y: 6)
    }
}
extension View {
    func e360MatchCard(themeColor: Color = E360Color.primary) -> some View {
        modifier(E360MatchRowCard(themeColor: themeColor))
    }
}

/// HUD stats chip
struct E360StatChip: View {
    let label: LocalizedStringKey
    let value: String
    var icon: String? = nil
    var color: Color = E360Color.accent

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(E360Font.number(16, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                Text(label)
                    .font(E360Font.body(9, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        }
    }
}

/// Team avatar with colored ring
struct E360TeamAvatar: View {
    let url: URL?
    let fallbackText: String
    var size: CGFloat = 56
    var ringColor: Color = E360Color.primary
    var ringWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [ringColor, ringColor.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: ringWidth
                )
                .frame(width: size + ringWidth * 3, height: size + ringWidth * 3)
                .shadow(color: ringColor.opacity(0.30), radius: 8)
            ESImageView(
                url: url,
                fallbackAsset: E360ImageAsset.teamPlaceholder,
                fallbackText: fallbackText
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}
