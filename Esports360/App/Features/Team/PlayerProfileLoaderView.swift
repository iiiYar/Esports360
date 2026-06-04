import SwiftUI

struct PlayerProfileLoaderView: View {
    let playerId: String
    let gameCode: String?
    
    @State private var profile: PlayerProfile? = nil
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    SkeletonRow(height: 120, cornerRadius: 12)
                    SkeletonRow(height: 220, cornerRadius: 12)
                    Spacer()
                }
                .padding()
                .background(E360Color.background.ignoresSafeArea())
                .onAppear {
                    loadProfile()
                }
            } else if let profile = profile {
                PlayerProfileView(player: profile, game: EsportsGame(backendCode: gameCode))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(E360Color.textSecondary)
                    
                    Text(String(localized: "discover.player.notfound", defaultValue: "لم يتم العثور على ملف اللاعب"))
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(E360Color.background.ignoresSafeArea())
            }
        }
    }
    
    private func loadProfile() {
        isLoading = true
        Task {
            // Fetch from mock data since player API is local-fallback only
            let player = MockEsportsData.playerProfile(id: playerId) ?? MockEsportsData.falconsRoster.first { $0.id == playerId } ?? MockEsportsData.falconsRoster[0]
            await MainActor.run {
                self.profile = player
                self.isLoading = false
            }
        }
    }
}
