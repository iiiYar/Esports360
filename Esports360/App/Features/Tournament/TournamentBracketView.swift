import SwiftUI

struct TournamentBracketView: View {
    let tournament: TournamentBracket
    @State private var zoom: CGFloat = 1
    @State private var progressionVisible = false
    @GestureState private var gestureZoom: CGFloat = 1

    /// Designated initialiser — no default value; caller must supply a real bracket.
    init(tournament: TournamentBracket) {
        self.tournament = tournament
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                bracketSurface
                GroupStageStandingsTable(standings: tournament.standings)
            }
            .padding(18)
            .padding(.bottom, 90)
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationTitle("feature.tournament.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: DeepLinkRouter.universalURL(for: .tournament(tournament.id))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("action.share"))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.65).delay(0.15)) {
                progressionVisible = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ESImageView(
                    url: tournament.tournament.imageURL,
                    fallbackAsset: E360ImageAsset.tournamentPlaceholder
                )
                .frame(width: 34, height: 34)

                Text(tournament.game.displayName)
                    .font(E360Font.number(12, weight: .bold)).foregroundStyle(E360Color.accent)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(E360Color.accent.opacity(0.12), in: Capsule())

                Spacer()
            }

            Text(tournament.tournament.name)
                .font(E360Font.display(28, weight: .black)).foregroundStyle(E360Color.textPrimary).lineLimit(2)

            Text("bracket.pinchHint")
                .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
        }
    }

    private var bracketSurface: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("bracket.knockout")
                    .font(E360Font.display(18, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { zoom = 1 }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered).tint(E360Color.primary)
                .accessibilityLabel(Text("bracket.resetZoom"))
            }

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                BracketCanvasView(rounds: tournament.rounds, progressionVisible: progressionVisible)
                    .scaleEffect(currentZoom, anchor: .topLeading)
                    .frame(
                        width:  250 * CGFloat(tournament.rounds.count) * currentZoom,
                        height: 176 * CGFloat(maxRoundSize) * currentZoom,
                        alignment: .topLeading
                    )
                    .gesture(
                        MagnificationGesture()
                            .updating($gestureZoom) { value, state, _ in state = value }
                            .onEnded { value in zoom = min(max(zoom * value, 0.72), 1.85) }
                    )
                    .padding(.vertical, 8)
            }
            .frame(minHeight: 360)
        }
        .padding(16)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(E360Color.divider, lineWidth: 1))
    }

    private var currentZoom: CGFloat { min(max(zoom * gestureZoom, 0.72), 1.85) }
    private var maxRoundSize: Int   { tournament.rounds.map(\.matches.count).max() ?? 1 }
}

private struct BracketCanvasView: View {
    let rounds: [BracketRound]
    let progressionVisible: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(rounds) { round in
                VStack(alignment: .leading, spacing: 14) {
                    Text(round.title)
                        .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.textSecondary).lineLimit(1)

                    ForEach(round.matches) { match in
                        HStack(spacing: 10) {
                            BracketMatchCard(match: match)
                            if round.id != rounds.last?.id {
                                Capsule()
                                    .fill(E360Color.primary.opacity(0.65))
                                    .frame(width: progressionVisible ? 38 : 0, height: 3)
                            }
                        }
                    }
                }
                .frame(width: 224, alignment: .topLeading)
            }
        }
    }
}

private struct BracketMatchCard: View {
    let match: BracketMatch
    var body: some View {
        VStack(spacing: 8) {
            BracketTeamLine(team: match.firstTeam,  score: match.firstScore,  isWinner: match.isWinner(match.firstTeam))
            BracketTeamLine(team: match.secondTeam, score: match.secondScore, isWinner: match.isWinner(match.secondTeam))
        }
        .padding(10)
        .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
    }
    private var borderColor: Color {
        match.winnerTeamID == nil ? E360Color.divider : E360Color.gold.opacity(0.75)
    }
}

private struct BracketTeamLine: View {
    let team: Team
    let score: Int
    let isWinner: Bool
    var body: some View {
        HStack(spacing: 8) {
            TeamAvatar(team: team, size: 26)
            Text(team.displayName)
                .font(E360Font.body(13, weight: isWinner ? .bold : .medium))
                .foregroundStyle(isWinner ? E360Color.textPrimary : E360Color.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(ArabicNumberFormatter.localized(score))
                .font(E360Font.number(14, weight: .bold))
                .foregroundStyle(isWinner ? E360Color.accent : E360Color.textSecondary)
            if isWinner {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(E360Color.gold)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(isWinner ? E360Color.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum StandingsSortColumn { case team, points, wins, losses, draws }

private struct GroupStageStandingsTable: View {
    let standings: [GroupStanding]
    @State private var sortColumn: StandingsSortColumn = .points
    @State private var sortAscending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("bracket.groupStage")
                .font(E360Font.display(18, weight: .bold)).foregroundStyle(E360Color.textPrimary)

            VStack(spacing: 0) {
                headerRow
                ForEach(sortedStandings) { standing in
                    Divider().overlay(E360Color.divider)
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            TeamAvatar(team: standing.team, size: 30)
                            Text(standing.team.displayName)
                                .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        StandingsCell(value: standing.points, highlighted: true)
                        StandingsCell(value: standing.wins)
                        StandingsCell(value: standing.losses)
                        StandingsCell(value: standing.draws)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 10)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(E360Color.divider, lineWidth: 1))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            sortButton(title: "bracket.team",   column: .team).frame(maxWidth: .infinity, alignment: .leading)
            sortButton(title: "bracket.points", column: .points)
            sortButton(title: "bracket.wins",   column: .wins)
            sortButton(title: "bracket.losses", column: .losses)
            sortButton(title: "bracket.draws",  column: .draws)
        }
        .padding(.vertical, 10)
    }

    private var sortedStandings: [GroupStanding] {
        standings.sorted { lhs, rhs in
            switch sortColumn {
            case .team:   return sortAscending ? lhs.team.name < rhs.team.name : lhs.team.name > rhs.team.name
            case .points: return sorted(lhs.points,  rhs.points,  lhs: lhs, rhs: rhs)
            case .wins:   return sorted(lhs.wins,    rhs.wins,    lhs: lhs, rhs: rhs)
            case .losses: return sorted(lhs.losses,  rhs.losses,  lhs: lhs, rhs: rhs)
            case .draws:  return sorted(lhs.draws,   rhs.draws,   lhs: lhs, rhs: rhs)
            }
        }
    }

    private func sortButton(title: LocalizedStringKey, column: StandingsSortColumn) -> some View {
        Button {
            if sortColumn == column { sortAscending.toggle() }
            else { sortColumn = column; sortAscending = column == .team || column == .losses }
        } label: {
            HStack(spacing: 3) {
                Text(title).font(E360Font.body(11, weight: .bold))
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(sortColumn == column ? E360Color.accent : E360Color.textSecondary)
            .frame(width: column == .team ? nil : 38, alignment: .center)
        }
        .buttonStyle(.plain)
    }

    private func sorted(_ lhsValue: Int, _ rhsValue: Int, lhs: GroupStanding, rhs: GroupStanding) -> Bool {
        guard lhsValue != rhsValue else { return lhs.team.name < rhs.team.name }
        return sortAscending ? lhsValue < rhsValue : lhsValue > rhsValue
    }
}

private struct StandingsCell: View {
    let value: Int
    var highlighted = false
    var body: some View {
        Text(ArabicNumberFormatter.localized(value))
            .font(E360Font.number(13, weight: .bold))
            .foregroundStyle(highlighted ? E360Color.gold : E360Color.textPrimary)
            .frame(width: 38)
    }
}
