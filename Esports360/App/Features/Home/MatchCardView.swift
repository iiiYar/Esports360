import SwiftUI
// Legacy MatchCardView — kept for backward compatibility with match detail references
// New home feed uses HomeMatchRow from HomeView.swift

struct MatchCardView: View {
    let match: BackendMatchDTO
    let isCompact: Bool

    private var game: EsportsGame { EsportsGame(backendCode: match.gameCode) }
    private var theme: Color { game.themeColor }
    private var isLive: Bool { match.status == "running" }

    var body: some View {
        if isCompact {
            HomeMatchRow(match: match)
        } else {
            HomeFeaturedMatchCard(match: match)
        }
    }
}

// Re-export for backward compat
extension HomeView {
    static func matchRow(_ match: BackendMatchDTO) -> some View {
        HomeMatchRow(match: match)
    }
}
