import Charts
import SwiftUI

// MARK: - PlayerProfileView — Phase-9
// ✔ Private PlayerSectionHeader → E360SectionHeader v2
// ✔ PlayerStatCard + poolGrid → e360GlassCard + cornerRadius 18
// ✔ e360RowHighlight on pool items

struct PlayerProfileView: View {
    let player: PlayerProfile
    let game:   EsportsGame
    private let poolColumns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    init(player: PlayerProfile = MockEsportsData.falconsRoster[0],
         game:   EsportsGame   = .valorant) {
        self.player = player
        self.game   = game
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                careerStats
                kdTrendChart
                poolGrid
            }
            .padding(18)
            .padding(.bottom, 90)
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationTitle("feature.player.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: DeepLinkRouter.universalURL(for: .player(player.id))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("action.share"))
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            PlayerAvatar(player: player, size: 76)

            VStack(alignment: .leading, spacing: 8) {
                Text(player.handle)
                    .font(E360Font.display(30, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(1)

                if let realName = player.realName {
                    Text(realName)
                        .font(E360Font.body(14, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                }

                HStack(spacing: 8) {
                    Text(player.role)
                        .font(E360Font.body(12, weight: .bold))
                        .foregroundStyle(E360Color.accent)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(E360Color.accent.opacity(0.12), in: Capsule())

                    Text(player.countryCode ?? "--")
                        .font(E360Font.number(12, weight: .bold))
                        .foregroundStyle(E360Color.gold)
                }
            }
            Spacer()
        }
    }

    // MARK: - Career Stats
    private var careerStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "player.careerStats",
                icon: "rectangle.grid.2x2.fill",
                iconColor: E360Color.primary
            )

            HStack(spacing: 10) {
                PlayerStatCard(
                    title: "player.kd",
                    value: String(format: "%.2f", player.kdRatio),
                    accent: E360Color.accent
                )
                PlayerStatCard(
                    title: "player.winRate",
                    value: "\(ArabicNumberFormatter.localized(Int(player.winRate)))%",
                    accent: E360Color.gold
                )
                PlayerStatCard(
                    title: "player.matches",
                    value: ArabicNumberFormatter.localized(player.matchesPlayed),
                    accent: E360Color.primary
                )
            }
        }
    }

    // MARK: - K/D Trend Chart
    private var kdTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "player.kdTrend",
                icon: "chart.xyaxis.line",
                iconColor: E360Color.accent
            )

            Chart(player.kdTrend) { point in
                LineMark(
                    x: .value("Match", point.label),
                    y: .value("K/D",   point.value)
                )
                .foregroundStyle(E360Color.primary)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Match", point.label),
                    y: .value("K/D",   point.value)
                )
                .foregroundStyle(E360Color.accent)
            }
            .chartYScale(domain: 0.8...1.45)
            .frame(height: 200)
            .padding(12)
            .e360GlassCard(cornerRadius: 18, borderOpacity: 0.12, shadowRadius: 10,
                           tintColor: E360Color.primary)
        }
    }

    // MARK: - Pool Grid
    private var poolGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "player.pool",
                icon: "square.grid.3x3.fill",
                iconColor: E360Color.gold
            )

            LazyVGrid(columns: poolColumns, spacing: 10) {
                ForEach(player.pool, id: \.self) { item in
                    VStack(spacing: 8) {
                        ESImageView(
                            url: RemoteAssetSources.poolIcon(item, game: game),
                            fallbackAsset: E360ImageAsset.gamePlaceholder
                        )
                        .frame(width: 42, height: 42)

                        Text(item)
                            .font(E360Font.body(13, weight: .bold))
                            .foregroundStyle(E360Color.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .e360GlassCard(cornerRadius: 18, borderOpacity: 0.12, shadowRadius: 8,
                                   tintColor: game.themeColor)
                    .e360RowHighlight()
                }
            }
        }
    }
}

// MARK: - PlayerStatCard
private struct PlayerStatCard: View {
    let title:  LocalizedStringKey
    let value:  String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(E360Font.body(11, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)

            Text(value)
                .font(E360Font.number(20, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .e360GlassCard(cornerRadius: 18, borderOpacity: 0.25, shadowRadius: 8,
                       tintColor: accent)
    }
}
