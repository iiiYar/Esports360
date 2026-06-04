import SwiftUI

enum E360Tab: Int, CaseIterable, Identifiable {
    case home = 0
    case saudiHub = 1
    case discover = 2
    case settings = 3

    var id: Int { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "dot.radiowaves.left.and.right"
        case .saudiHub: return "trophy.fill"
        case .discover: return "gamecontroller.fill"
        case .settings: return "slider.horizontal.3"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "tab.home"
        case .saudiHub: return "tab.saudiHub"
        case .discover: return "tab.discover"
        case .settings: return "tab.settings"
        }
    }
}

struct E360TabBar: View {
    @Binding var selectedTab: E360Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(E360Tab.allCases) { tab in
                let isSelected = selectedTab == tab
                
                Button {
                    if selectedTab != tab {
                        HapticManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                            selectedTab = tab
                        }
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? E360Color.accent : E360Color.textSecondary)
                            .scaleEffect(isSelected ? 1.18 : 1.0)
                        
                        Text(tab.title)
                            .font(E360Font.body(10, weight: isSelected ? .black : .bold))
                            .foregroundStyle(isSelected ? E360Color.textPrimary : E360Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(E360Color.surface.opacity(0.48), in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.clear,
                            E360Color.accent.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .padding(.horizontal, 24)
        .shadow(color: Color.black.opacity(0.38), radius: 16, y: 10)
    }
}
