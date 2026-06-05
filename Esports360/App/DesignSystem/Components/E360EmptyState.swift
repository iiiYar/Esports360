import SwiftUI

// MARK: - E360EmptyState
// Unified empty / error / loading state component
// Used across: Home, Discover, Tournaments, SaudiHub, Teams
//
// Usage:
//   E360EmptyState(style: .noMatches)
//   E360EmptyState(style: .error(message: "..."), onRetry: { ... })
//   E360EmptyState(style: .noResults(query: "csgo"))

enum E360EmptyStateStyle {
    case noMatches
    case noResults(query: String)
    case noTournaments
    case noTeams
    case noFavorites
    case offline
    case error(message: String)
    case custom(icon: String, title: String, subtitle: String, iconColor: Color)

    var icon: String {
        switch self {
        case .noMatches:         return "sportscourt"
        case .noResults:         return "magnifyingglass"
        case .noTournaments:     return "trophy"
        case .noTeams:           return "person.3"
        case .noFavorites:       return "star.slash"
        case .offline:           return "wifi.slash"
        case .error:             return "exclamationmark.triangle"
        case .custom(let icon, _, _, _): return icon
        }
    }

    var iconColor: Color {
        switch self {
        case .offline:           return E360Color.warning
        case .error:             return E360Color.error
        case .custom(_, _, _, let c): return c
        default:                 return E360Color.textTertiary
        }
    }

    var title: String {
        switch self {
        case .noMatches:         return String(localized: "empty.noMatches.title",         defaultValue: "لا توجد مباريات")
        case .noResults(let q):  return String(localized: "empty.noResults.title",         defaultValue: "\u0644\u0627 \u0646\u062a\u0627\u0626\u062c \u0644\u0640 \"\(q)\"")
        case .noTournaments:     return String(localized: "empty.noTournaments.title",     defaultValue: "لا توجد بطولات")
        case .noTeams:           return String(localized: "empty.noTeams.title",           defaultValue: "لا توجد فرق")
        case .noFavorites:       return String(localized: "empty.noFavorites.title",       defaultValue: "لا يوجد مفضلات")
        case .offline:           return String(localized: "empty.offline.title",           defaultValue: "لا يوجد اتصال بالإنترنت")
        case .error:             return String(localized: "empty.error.title",             defaultValue: "حدث خطأ")
        case .custom(_, let t, _, _): return t
        }
    }

    var subtitle: String {
        switch self {
        case .noMatches:         return String(localized: "empty.noMatches.sub",      defaultValue: "جرّب يومًا آخر أو غيّر فلتر اللعبة")
        case .noResults(let q):  return String(localized: "empty.noResults.sub",      defaultValue: "\u062c\u0631\u0651\u0628 \u0643\u0644\u0645\u0629 \u0623\u062e\u0631\u0649 \u0628\u062f\u0644\u0627\u064b \u0645\u0646 \"\(q)\"")
        case .noTournaments:     return String(localized: "empty.noTournaments.sub",  defaultValue: "تابع التحديثات لمعرفة أحدث البطولات")
        case .noTeams:           return String(localized: "empty.noTeams.sub",        defaultValue: "ابحث عن فرقك المفضلة في قسم اكتشف")
        case .noFavorites:       return String(localized: "empty.noFavorites.sub",    defaultValue: "اتبع فرقًا وبطولات لتراها هنا")
        case .offline:           return String(localized: "empty.offline.sub",        defaultValue: "تحقّق من الاتصال بالإنترنت وأعد المحاولة")
        case .error(let msg):    return msg
        case .custom(_, _, let s, _): return s
        }
    }
}

struct E360EmptyState: View {
    let style: E360EmptyStateStyle
    var onRetry: (() -> Void)? = nil
    var onAction: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(style.iconColor.opacity(0.10))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(style.iconColor.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                Image(systemName: style.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(style.iconColor)
            }

            // Text
            VStack(spacing: 6) {
                Text(style.title)
                    .font(E360Font.display(18, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(style.subtitle)
                    .font(E360Font.body(13, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Actions
            HStack(spacing: 12) {
                if let onRetry {
                    Button {
                        HapticManager.shared.triggerImpact(style: .light)
                        onRetry()
                    } label: {
                        Label(
                            String(localized: "common.retry", defaultValue: "إعادة المحاولة"),
                            systemImage: "arrow.clockwise"
                        )
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.accent)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(E360Color.accentGlow, in: Capsule())
                        .overlay(Capsule().stroke(E360Color.accent.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(E360PressScale())
                }

                if let onAction, let label = actionLabel {
                    Button {
                        HapticManager.shared.triggerSelection()
                        onAction()
                    } label: {
                        Text(label)
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.textSecondary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .background(E360Color.tintedSurface, in: Capsule())
                            .overlay(Capsule().stroke(E360Color.dividerStrong, lineWidth: 1))
                    }
                    .buttonStyle(E360PressScale())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Convenience shimmer skeleton for lists
struct E360LoadingList: View {
    var count: Int = 4
    var rowHeight: CGFloat = 88
    var spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { i in
                SkeletonRow(height: rowHeight)
                    .opacity(1.0 - (Double(i) * 0.15))
            }
        }
    }
}
