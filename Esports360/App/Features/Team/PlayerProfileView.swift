import Charts
import SwiftUI

struct PlayerProfileView: View {
    let player: PlayerProfile
    let game: EsportsGame
    private let poolColumns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    init(player: PlayerProfile = MockEsportsData.falconsRoster[0], game: EsportsGame = .valorant) {
        self.player = player
        self.game = game
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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(E360Color.accent.opacity(0.12), in: Capsule())

                    Text(player.countryCode ?? "--")
                        .font(E360Font.number(12, weight: .bold))
                        .foregroundStyle(E360Color.gold)
                }
            }

            Spacer()
        }
    }

    private var careerStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlayerSectionHeader(title: "player.careerStats", systemImage: "rectangle.grid.2x2.fill")

            HStack(spacing: 10) {
                PlayerStatCard(title: "player.kd", value: String(format: "%.2f", player.kdRatio), accent: E360Color.accent)
                PlayerStatCard(title: "player.winRate", value: "\(ArabicNumberFormatter.localized(Int(player.winRate)))%", accent: E360Color.gold)
                PlayerStatCard(title: "player.matches", value: ArabicNumberFormatter.localized(player.matchesPlayed), accent: E360Color.primary)
            }
        }
    }

    private var kdTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlayerSectionHeader(title: "player.kdTrend", systemImage: "chart.xyaxis.line")

            Chart(player.kdTrend) { point in
                LineMark(
                    x: .value("Match", point.label),
                    y: .value("K/D", point.value)
                )
                .foregroundStyle(E360Color.primary)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Match", point.label),
                    y: .value("K/D", point.value)
                )
                .foregroundStyle(E360Color.accent)
            }
            .chartYScale(domain: 0.8...1.45)
            .frame(height: 200)
            .padding(12)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(E360Color.divider, lineWidth: 1)
            )
        }
    }

    private var poolGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlayerSectionHeader(title: "player.pool", systemImage: "square.grid.3x3.fill")

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
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(E360Color.divider, lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct PlayerSectionHeader: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(E360Color.primary)

            Text(title)
                .font(E360Font.display(18, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)
        }
    }
}

private struct PlayerStatCard: View {
    let title: LocalizedStringKey
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(E360Font.body(11, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(E360Font.number(20, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    }
}
