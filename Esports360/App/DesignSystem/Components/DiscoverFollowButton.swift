import SwiftUI

struct DiscoverFollowButton: View {
    let teamId: String
    let teamName: String
    let themeColor: Color
    
    @ObservedObject private var authService = UserAuthService.shared
    @State private var isAnimating = false
    
    private var isFollowed: Bool {
        authService.followedEntities.contains { $0.entityType == "team" && $0.entityId == teamId }
    }
    
    var body: some View {
        Button {
            handleToggleFollow()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isFollowed ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .bold))
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                
                Text(isFollowed ? String(localized: "action.following", defaultValue: "متابع") : String(localized: "action.follow", defaultValue: "متابعة"))
                    .font(E360Font.body(11, weight: .bold))
            }
            .foregroundStyle(isFollowed ? themeColor : E360Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isFollowed {
                        themeColor.opacity(0.12)
                    } else {
                        themeColor
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isFollowed ? themeColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isAnimating ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isFollowed)
        }
        .buttonStyle(.plain)
    }
    
    private func handleToggleFollow() {
        HapticManager.shared.triggerImpact(style: .light)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        Task {
            if isFollowed {
                await authService.unfollow(entityType: "team", entityId: teamId)
            } else {
                await authService.follow(entityType: "team", entityId: teamId)
            }
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isAnimating = false
            }
        }
    }
}
