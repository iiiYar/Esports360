import Charts
import SwiftUI

// MARK: - TeamProfileView — Phase-12 Final
// ✔ Private SectionHeader → E360SectionHeader v2
// ✔ ShareLink route fix: .team(id: profile.id)
// ✔ e360RowHighlight on roster cards
// ✔ PlayerRosterCard cornerRadius 18

struct TeamProfileView: View {
    let profile: TeamProfile
    private let rosterColumns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    init(profile: TeamProfile = MockEsportsData.teamFalconsProfile) {
        self.profile = profile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                rosterGrid
                formStrip
                winRateChart
                recentResults
            }
            .padding(18)
            .padding(.bottom, 90)
        }
        .background(
            ZStack {
                E360Color.background.ignoresSafeArea()
                LinearGradient(
                    colors: [profile.game.themeColor.opacity(0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 220).ignoresSafeArea()
            }
        )
        .navigationTitle("feature.team.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: DeepLinkRouter.universalURL(for: .team(id: profile.id))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("action.share"))
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [profile.game.themeColor.opacity(0.14), profile.game.themeColor.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(profile.game.themeColor.opacity(0.24), lineWidth: 1))
            .shadow(color: profile.game.themeColor.opacity(0.06), radius: 10)

            HStack(alignment: .center, spacing: 14) {
                TeamAvatar(team: profile.team, size: 70, game: profile.game, isLive: false)
                    .shadow(color: profile.game.themeColor.opacity(0.24), radius: 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.team.name)
                        .font(E360Font.display(24, weight: .black))
                        .foregroundStyle(E360Color.textPrimary).lineLimit(1)

                    HStack(spacing: 8) {
                        ESImageView(url: profile.displayGameImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                            .frame(width: 18, height: 18)
                        Text(profile.game.displayName)
                            .font(E360Font.number(12, weight: .bold)).foregroundStyle(profile.game.themeColor)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(profile.game.themeColor.opacity(0.12), in: Capsule())
                        Text(profile.team.countryCode ?? "--")
                            .font(E360Font.number(12, weight: .bold)).foregroundStyle(E360Color.gold)
                    }
                }
                Spacer()
            }
            .padding(14)
        }
    }

    // MARK: - Roster Grid
    private var rosterGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "team.roster",
                icon: "person.3.fill",
                iconColor: E360Color.primary
            )

            if profile.roster.isEmpty {
                E360EmptyState(
                    style: .custom(
                        icon: "person.3",
                        title: String(localized: "team.emptyRoster", defaultValue: "لا يوجد لاعبون في القائمة"),
                        subtitle: "",
                        iconColor: E360Color.textTertiary
                    )
                )
            } else {
                LazyVGrid(columns: rosterColumns, spacing: 10) {
                    ForEach(profile.roster) { player in
                        NavigationLink {
                            PlayerProfileView(player: player, game: profile.game)
                        } label: {
                            PlayerRosterCard(player: player)
                        }
                        .buttonStyle(.plain)
                        .e360RowHighlight()
                    }
                }
            }
        }
    }

    // MARK: - Form Strip
    private var formStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "team.form",
                icon: "waveform.path.ecg",
                iconColor: E360Color.accent
            )

            HStack(spacing: 10) {
                ForEach(Array(profile.form.enumerated()), id: \.offset) { _, outcome in
                    OutcomeBadge(outcome: outcome)
                }
                Spacer()
                Text("team.lastFive")
                    .font(E360Font.body(12, weight: .semibold)).foregroundStyle(E360Color.textSecondary)
            }
            .padding(14)
            .e360GlassCard(cornerRadius: 16)
        }
    }

    // MARK: - Win Rate Chart
    private var winRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                E360SectionHeader(
                    title: "team.winRate",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: E360Color.accent
                )
                Spacer()
                Text("\(ArabicNumberFormatter.localized(Int(profile.winRateHistory.last?.value ?? 0)))%")
                    .font(E360Font.number(18, weight: .bold)).foregroundStyle(E360Color.accent)
            }

            Chart(profile.winRateHistory) { point in
                LineMark(
                    x: .value("Week", point.label),
                    y: .value("Win Rate", point.value)
                )
                .foregroundStyle(E360Color.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Week", point.label),
                    y: .value("Win Rate", point.value)
                )
                .foregroundStyle(LinearGradient(
                    colors: [E360Color.accent.opacity(0.24), E360Color.accent.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            .chartYScale(domain: 40...80)
            .frame(height: 190)
            .padding(12)
            .e360GlassCard(cornerRadius: 16, tintColor: E360Color.accent)
        }
    }

    // MARK: - Recent Results
    private var recentResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "team.recentResults",
                icon: "clock.arrow.circlepath",
                iconColor: E360Color.gold
            )

            VStack(spacing: 0) {
                if profile.recentResults.isEmpty {
                    Text("team.emptyResults")
                        .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                } else {
                    ForEach(profile.recentResults.prefix(5)) { result in
                        RecentResultRow(result: result)
                        if result.id != profile.recentResults.prefix(5).last?.id {
                            Divider().overlay(E360Color.divider)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .e360GlassCard(cornerRadius: 16)
        }
    }
}

// MARK: - PlayerRosterCard
private struct PlayerRosterCard: View {
    let player: PlayerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PlayerAvatar(player: player, size: 42)
                Spacer()
                Text(player.countryCode ?? "--")
                    .font(E360Font.number(11, weight: .bold)).foregroundStyle(E360Color.gold)
            }
            Text(player.handle)
                .font(E360Font.body(15, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
            Text(player.role)
                .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
            HStack {
                Text("K/D").font(E360Font.number(11, weight: .bold)).foregroundStyle(E360Color.textTertiary)
                Spacer()
                Text(String(format: "%.2f", player.kdRatio))
                    .font(E360Font.number(13, weight: .bold)).foregroundStyle(E360Color.accent)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .e360GlassCard(cornerRadius: 18, borderOpacity: 0.12, shadowRadius: 8)
    }
}

// MARK: - PlayerAvatar
struct PlayerAvatar: View {
    let player: PlayerProfile
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(E360Color.elevatedSurface)
                .overlay(Circle().stroke(E360Color.divider, lineWidth: 1))
            if let imageURL = player.imageURL {
                ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.playerPlaceholder, contentMode: .fill)
            } else {
                ESImageView(url: nil, fallbackAsset: E360ImageAsset.playerPlaceholder)
                    .opacity(0.42).overlay(initials).padding(3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: some View {
        Text(String(player.handle.prefix(2)).uppercased())
            .font(E360Font.number(size * 0.28, weight: .bold)).foregroundStyle(E360Color.textPrimary)
    }
}

// MARK: - OutcomeBadge
private struct OutcomeBadge: View {
    let outcome: MatchOutcome
    var body: some View {
        Text(outcome.rawValue)
            .font(E360Font.number(13, weight: .bold))
            .foregroundStyle(outcome.isPositive ? E360Color.accent : E360Color.live)
            .frame(width: 34, height: 34)
            .background(outcome.isPositive ? E360Color.accent.opacity(0.14) : E360Color.live.opacity(0.14), in: Circle())
            .overlay(Circle().stroke(outcome.isPositive ? E360Color.accent.opacity(0.45) : E360Color.live.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - RecentResultRow
private struct RecentResultRow: View {
    let result: TeamMatchResult
    var body: some View {
        HStack(spacing: 12) {
            OutcomeBadge(outcome: result.outcome)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.opponent.name)
                    .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
                Text(result.tournamentName)
                    .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
            Spacer()
            Text(result.score)
                .font(E360Font.number(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
        }
        .padding(.vertical, 12)
    }
}
