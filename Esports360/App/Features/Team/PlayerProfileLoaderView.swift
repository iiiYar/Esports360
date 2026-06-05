import SwiftUI

// MARK: - PlayerProfileLoaderView — Phase-9
// ✔ E360SkeletonList(.playerCard) replaces SkeletonRow
// ✔ .task async load + retry state
// ✔ E360StatusBanner on error

struct PlayerProfileLoaderView: View {
    let playerId: String
    let gameCode: String?

    @State private var profile:   PlayerProfile?
    @State private var isLoading  = true
    @State private var hasFailed  = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    E360SkeletonList(type: .playerCard, count: 2)
                    Spacer()
                }
                .padding(18)
                .background(E360Color.background.ignoresSafeArea())

            } else if let profile {
                PlayerProfileView(player: profile, game: EsportsGame(backendCode: gameCode))

            } else {
                VStack(spacing: 20) {
                    E360StatusBanner(
                        style: .error(
                            String(localized: "discover.player.notfound",
                                   defaultValue: "لم يتم العثور على ملف اللاعب")
                        ),
                        onDismiss: nil
                    )

                    Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                        hasFailed  = false
                        isLoading  = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(E360Color.primary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(E360Color.background.ignoresSafeArea())
            }
        }
        .task(id: playerId) { await loadProfile() }
        .onChange(of: isLoading) { _, newValue in
            if newValue { Task { await loadProfile() } }
        }
    }

    @MainActor
    private func loadProfile() async {
        isLoading = true
        hasFailed = false
        let player = MockEsportsData.playerProfile(id: playerId)
            ?? MockEsportsData.falconsRoster.first { $0.id == playerId }
            ?? MockEsportsData.falconsRoster.first
        profile   = player
        hasFailed = player == nil
        isLoading = false
    }
}
