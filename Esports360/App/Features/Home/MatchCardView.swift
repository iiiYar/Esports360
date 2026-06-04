import SwiftUI

struct MatchCardView: View {
    let match: Match

    var body: some View {
        VStack(spacing: 0) {
            cardHeader

            VStack(spacing: 16) {
                scoreboard
                liveContext
            }
            .padding(16)
        }
        .e360Card(
            highlighted: match.status.isLive || match.isFeaturedSaudiMatch,
            borderColor: match.isFeaturedSaudiMatch ? E360Color.gold.opacity(0.55) : (match.status.isLive ? match.game.themeColor.opacity(0.35) : nil),
            game: match.game
        )
    }

    private var cardHeader: some View {
        HStack(spacing: 10) {
            if match.status.isLive {
                LiveBadge()
            }

            GameChip(game: match.game)

            Text(match.tournament?.leagueName ?? match.tournament?.name ?? "Tournament")
                .font(E360Font.body(13, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1)

            Spacer()

            Text(timeText)
                .font(E360Font.mono(11, weight: .bold))
                .foregroundStyle(match.status.isLive ? match.game.themeColor : E360Color.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                if match.status.isLive {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(match.game.themeColor.opacity(0.08))
                } else {
                    E360Color.elevatedSurface.opacity(0.64)
                }
            }
        )
        .overlay(
            VStack {
                Spacer()
                Rectangle()
                    .fill(match.status.isLive ? match.game.themeColor.opacity(0.24) : E360Color.divider)
                    .frame(height: 1)
            }
        )
    }

    private var scoreboard: some View {
        HStack(alignment: .center, spacing: 12) {
            TeamColumn(
                team: match.firstTeam,
                score: match.firstTeam.map { match.score(for: $0) } ?? 0,
                isLeading: match.firstTeam.map(isLeading) ?? false,
                game: match.game,
                isLive: match.status.isLive,
                alignment: .leading
            )

            VStack(spacing: 8) {
                Text(":")
                    .font(E360Font.number(30, weight: .black))
                    .foregroundStyle(match.status.isLive ? match.game.themeColor.opacity(0.8) : E360Color.textTertiary)
                    .offset(y: -4)

                Text("BO\(match.bestOf)")
                    .font(E360Font.mono(11, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(E360Color.elevatedSurface, in: Capsule())
                    .overlay(Capsule().stroke(E360Color.divider, lineWidth: 1))
            }
            .frame(width: 42)

            TeamColumn(
                team: match.secondTeam,
                score: match.secondTeam.map { match.score(for: $0) } ?? 0,
                isLeading: match.secondTeam.map(isLeading) ?? false,
                game: match.game,
                isLive: match.status.isLive,
                alignment: .trailing
            )
        }
    }

    @ViewBuilder
    private var liveContext: some View {
        if let liveState = match.liveState, match.status.isLive {
            HStack(spacing: 10) {
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(match.game.themeColor)
                
                Text(liveState.phase)
                    .font(E360Font.body(12, weight: .bold))
                
                Text("•")
                
                Text(String(format: String(localized: "match.mapNumber"), ArabicNumberFormatter.localized(liveState.mapNumber)))
                
                if let roundNumber = liveState.roundNumber {
                    Text(String(format: String(localized: "match.roundNumber"), ArabicNumberFormatter.localized(roundNumber)))
                }
                
                Spacer()
                
                // Visual Map Progression Gems
                MapGemsView(bestOf: match.bestOf, currentMap: liveState.mapNumber, game: match.game)
                    .padding(.trailing, 4)
                
                if let clock = liveState.clock {
                    Text(clock)
                        .font(E360Font.mono(12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(E360Color.textPrimary)
                }
            }
            .font(E360Font.body(12, weight: .semibold))
            .foregroundStyle(E360Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(E360Color.elevatedSurface, in: Capsule())
            .overlay(
                Capsule().stroke(match.game.themeColor.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var timeText: String {
        switch match.status {
        case .finished:
            String(localized: "match.finished")
        case .cancelled:
            String(localized: "match.cancelled")
        default:
            match.beginAt.map { E360DateFormatter.matchTime($0) } ?? "--"
        }
    }

    private func isLeading(_ team: Team) -> Bool {
        let score = match.score(for: team)
        let maxScore = match.teams.map(match.score(for:)).max() ?? 0
        return score > 0 && score == maxScore
    }
}

struct MapGemsView: View {
    let bestOf: Int
    let currentMap: Int
    let game: EsportsGame

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...bestOf, id: \.self) { mapIndex in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(mapColor(for: mapIndex))
                    .frame(width: 12, height: 6)
                    .scaleEffect(mapIndex == currentMap ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentMap)
            }
        }
    }

    private func mapColor(for index: Int) -> Color {
        if index < currentMap {
            return game.themeColor // Finished maps
        } else if index == currentMap {
            return E360Color.accent // Current live map
        } else {
            return E360Color.textTertiary // Future maps
        }
    }
}

private struct GameChip: View {
    let game: EsportsGame

    var body: some View {
        HStack(spacing: 6) {
            Text(game.shortName)
                .font(E360Font.mono(11, weight: .black))
                .foregroundStyle(game.themeColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(game.themeColor.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(game.themeColor.opacity(0.24), lineWidth: 1))
    }
}

private struct TeamColumn: View {
    let team: Team?
    let score: Int
    let isLeading: Bool
    let game: EsportsGame
    let isLive: Bool
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 10) {
            TeamAvatar(team: team, size: 48, game: game, isLive: isLive)

            VStack(alignment: alignment, spacing: 4) {
                Text(team?.displayName ?? "TBD")
                    .font(E360Font.body(15, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let acronym = team?.acronym, acronym.isEmpty == false {
                    Text(acronym)
                        .font(E360Font.mono(11, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                }
            }

            ScorePill(
                score: ArabicNumberFormatter.localized(score),
                isLeading: isLeading
            )
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

struct TeamAvatar: View {
    let team: Team?
    let size: CGFloat
    var game: EsportsGame? = nil
    var isLive: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(E360Color.elevatedSurface)
                .overlay(
                    Circle()
                        .stroke(
                            (isLive && game != nil) ? game!.themeColor.opacity(0.55) : E360Color.divider,
                            lineWidth: (isLive && game != nil) ? 2 : 1
                        )
                )
                .shadow(color: (isLive && game != nil) ? game!.themeColor.opacity(0.36) : E360Color.primary.opacity(0.08), radius: (isLive && game != nil) ? 8 : 4)

            if let imageURL = team?.imageURL {
                ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.teamPlaceholder)
                    .padding(6)
            } else {
                ESImageView(url: nil, fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: team?.displayName)
                    .opacity(0.36)
                    .padding(6)
            }
        }
        .frame(width: size, height: size)
    }
}
