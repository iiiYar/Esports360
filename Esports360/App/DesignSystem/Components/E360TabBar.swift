import SwiftUI

// MARK: - E360Tab  (Phase-1 — 5 tabs, HIG-compliant)
// Rules enforced:
//   • 3-5 top-level destinations only
//   • Each tab owns an independent NavigationStack
//   • Tab bar is for navigation only — no action buttons
//   • Pop-to-root on double-tap (standard iOS pattern)
enum E360Tab: Int, CaseIterable, Identifiable {
    case home        = 0
    case tournaments = 1
    case discover    = 2
    case saudiHub    = 3
    case settings    = 4

    var id: Int { rawValue }

    // SF Symbols — outlined when inactive, filled when active
    var systemImage: String {
        switch self {
        case .home:        return "house"
        case .tournaments: return "trophy"
        case .discover:    return "safari"
        case .saudiHub:    return "star"
        case .settings:    return "gearshape"
        }
    }
    var activeImage: String {
        switch self {
        case .home:        return "house.fill"
        case .tournaments: return "trophy.fill"
        case .discover:    return "safari.fill"
        case .saudiHub:    return "star.fill"
        case .settings:    return "gearshape.fill"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .home:        return "tab.home"
        case .tournaments: return "tab.tournaments"
        case .discover:    return "tab.discover"
        case .saudiHub:    return "tab.saudiHub"
        case .settings:    return "tab.settings"
        }
    }

    // Every tab has its own accent — creates identity per section
    var accentColor: Color {
        switch self {
        case .home:        return E360Color.accent
        case .tournaments: return E360Color.gold
        case .discover:    return E360Color.primaryBright
        case .saudiHub:    return Color(red: 0.0, green: 0.72, blue: 0.42) // Saudi green
        case .settings:    return E360Color.textSecondary
        }
    }
}

// MARK: - E360TabBar — iOS 26 Floating Glass  (Phase-1)
struct E360TabBar: View {
    @Binding var selectedTab: E360Tab
    /// Called when user taps the ALREADY-selected tab → pop to root
    var onSameTabTap: ((E360Tab) -> Void)? = nil

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(E360Tab.allCases) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            // Liquid-glass layered background
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(E360Color.surface.opacity(0.55))
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .clear, E360Color.accent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.40), radius: 22, y: 14)
    }

    // MARK: - Tab item
    @ViewBuilder
    private func tabItem(_ tab: E360Tab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            if isSelected {
                // Pop to root on double-tap (standard iOS behaviour)
                HapticManager.shared.triggerImpact(style: .light)
                onSameTabTap?(tab)
            } else {
                HapticManager.shared.triggerSelection()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    selectedTab = tab
                }
            }
        } label: {
            ZStack {
                // Sliding active pill
                if isSelected {
                    Capsule()
                        .fill(tab.accentColor.opacity(0.14))
                        .frame(height: 42)
                        .matchedGeometryEffect(id: "tab_pill", in: indicator)
                        .overlay {
                            Capsule()
                                .stroke(tab.accentColor.opacity(0.28), lineWidth: 1)
                        }
                }

                VStack(spacing: 3) {
                    // Icon
                    Image(systemName: isSelected ? tab.activeImage : tab.systemImage)
                        .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? tab.accentColor : E360Color.textTertiary)
                        .scaleEffect(isSelected ? 1.10 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isSelected)

                    // Label
                    Text(tab.title)
                        .font(E360Font.rounded(9, weight: isSelected ? .black : .medium))
                        .foregroundStyle(isSelected ? tab.accentColor : E360Color.textTertiary)
                        .animation(.easeOut(duration: 0.18), value: isSelected)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
