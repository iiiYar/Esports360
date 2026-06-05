import SwiftUI

// MARK: - E360Tab
enum E360Tab: Int, CaseIterable, Identifiable {
    case home     = 0
    case saudiHub = 1
    case discover = 2
    case settings = 3

    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .home:     return "dot.radiowaves.left.and.right"
        case .saudiHub: return "trophy.fill"
        case .discover: return "gamecontroller.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
    var selectedImage: String {
        switch self {
        case .home:     return "dot.radiowaves.left.and.right"
        case .saudiHub: return "trophy.fill"
        case .discover: return "gamecontroller.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
    var title: LocalizedStringKey {
        switch self {
        case .home:     return "tab.home"
        case .saudiHub: return "tab.saudiHub"
        case .discover: return "tab.discover"
        case .settings: return "tab.settings"
        }
    }
    var accentColor: Color {
        switch self {
        case .home:     return E360Color.accent
        case .saudiHub: return E360Color.gold
        case .discover: return E360Color.primaryBright
        case .settings: return E360Color.textSecondary
        }
    }
}

// MARK: - E360TabBar — iOS 26 Floating Glass
struct E360TabBar: View {
    @Binding var selectedTab: E360Tab
    @Namespace private var tabIndicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(E360Tab.allCases) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
            Capsule()
                .fill(E360Color.surface.opacity(0.60))
            Capsule()
                .stroke(LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.clear,
                        E360Color.accent.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1.2)
        }
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
    }

    @ViewBuilder
    private func tabItem(_ tab: E360Tab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            guard selectedTab != tab else { return }
            HapticManager.shared.triggerSelection()
            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // Active indicator pill
                if isSelected {
                    Capsule()
                        .fill(tab.accentColor.opacity(0.15))
                        .frame(height: 42)
                        .matchedGeometryEffect(id: "tab_indicator", in: tabIndicator)
                        .overlay {
                            Capsule().stroke(tab.accentColor.opacity(0.25), lineWidth: 1)
                        }
                }
                VStack(spacing: 4) {
                    Image(systemName: isSelected ? tab.selectedImage : tab.systemImage)
                        .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? tab.accentColor : E360Color.textSecondary)
                        .scaleEffect(isSelected ? 1.12 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                    Text(tab.title)
                        .font(E360Font.rounded(9, weight: isSelected ? .black : .semibold))
                        .foregroundStyle(isSelected ? tab.accentColor : E360Color.textTertiary)
                        .animation(.easeOut(duration: 0.2), value: isSelected)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
