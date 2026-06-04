import SwiftUI

// MARK: - HomeView — iOS 26 Redesign
// Architecture: Stateless view — all state lives in HomeViewModel
// UX: Hero match card, live pill strip, game filter chips, match feed

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                E360Color.background.ignoresSafeArea()
                E360AmbientGlow()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Hero header
                        HomeHeroHeader(viewModel: viewModel)
                            .padding(.bottom, 24)

                        // Live now strip
                        if !viewModel.liveMatches.isEmpty {
                            HomeLiveStrip(matches: viewModel.liveMatches)
                                .padding(.bottom, 24)
                        }

                        // Game filter chips
                        HomeGameFilter(
                            games: viewModel.availableGames,
                            selected: $viewModel.selectedGameFilter
                        )
                        .padding(.bottom, 20)

                        // Today's match feed
                        HomeMatchFeed(viewModel: viewModel)
                            .padding(.bottom, 100) // tab bar clearance
                    }
                }
                .refreshable { await viewModel.refresh() }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Hero Header
private struct HomeHeroHeader: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App title row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.greeting", defaultValue: "مرحباً ✨"))
                        .font(E360Font.body(14, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                    Text(String(localized: "home.title", defaultValue: "الرياضة الإلكترونية"))
                        .font(E360Font.display(28, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                }
                Spacer()
                // Live count badge
                if viewModel.liveMatches.isEmpty == false {
                    HStack(spacing: 6) {
                        E360LivePulse(size: 6)
                        Text(String(
                            format: String(localized: "home.liveCount", defaultValue: "%@ مباشر"),
                            "\(viewModel.liveMatches.count)"
                        ))
                        .font(E360Font.mono(11, weight: .bold))
                        .foregroundStyle(E360Color.live)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(E360Color.liveGlow, in: Capsule())
                    .overlay(Capsule().stroke(E360Color.live.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Hero Featured Match
            if viewModel.isLoading {
                SkeletonRow(height: 190, cornerRadius: 28)
                    .padding(.horizontal, 16)
            } else if let featured = viewModel.featuredMatch {
                NavigationLink(destination: MatchDetailContainerView(matchID: featured.id)) {
                    HomeFeaturedMatchCard(match: featured)
                }
                .buttonStyle(E360PressScale(scale: 0.97))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Featured Hero Card
private struct HomeFeaturedMatchCard: View {
    let match: BackendMatchDTO
    @State private var shimmer = false

    private var esportsGame: EsportsGame { EsportsGame(backendCode: match.gameCode) }
    private var theme: Color { esportsGame.themeColor }
    private var isLive: Bool { match.status == "running" }

    var body: some View {
        VStack(spacing: 0) {
            // Game strip
            HStack {
                E360Badge(text: esportsGame.shortName, color: theme)
                Spacer()
                if isLive {
                    HStack(spacing: 5) {
                        E360LivePulse(size: 5)
                        Text(String(localized: "match.live", defaultValue: "مباشر الآن"))
                            .font(E360Font.mono(10, weight: .black))
                            .foregroundStyle(E360Color.live)
                    }
                } else if let t = match.scheduledAt {
                    Text(t, style: .time)
                        .font(E360Font.mono(12, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)

            // Teams vs
            HStack(spacing: 0) {
                // Team 1
                teamSide(name: match.team1Name, imageURL: BackendURLResolver.resolveBackendURL(match.team1ImageUrl), score: match.team1Score, align: .leading)

                // VS separator
                E360VsSeparator()
                    .padding(.horizontal, 12)

                // Team 2
                teamSide(name: match.team2Name, imageURL: BackendURLResolver.resolveBackendURL(match.team2ImageUrl), score: match.team2Score, align: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 18).padding(.bottom, 16)

            // Tournament footer
            if let tName = match.tournamentName {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.opacity(0.8))
                    Text(tName)
                        .font(E360Font.body(11, weight: .semibold))
                        .foregroundStyle(E360Color.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(E360Color.textTertiary)
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(E360Color.surface)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(
                        colors: [theme.opacity(0.13), theme.opacity(0.03), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                if isLive {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(E360Color.live.opacity(0.30), lineWidth: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LinearGradient(
                            colors: [theme.opacity(0.35), E360Color.divider],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1)
                }
            }
        }
        .shadow(color: theme.opacity(isLive ? 0.20 : 0.08), radius: isLive ? 18 : 10, y: 8)
    }

    @ViewBuilder
    private func teamSide(name: String?, imageURL: URL?, score: Int?, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 8) {
            ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: name ?? "")
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .shadow(color: theme.opacity(0.25), radius: 8)

            Text(name ?? "-")
                .font(E360Font.body(13, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 100)

            if let score {
                Text("\(score)")
                    .font(E360Font.number(26, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
            } else if isLive {
                Text("–")
                    .font(E360Font.number(26, weight: .black))
                    .foregroundStyle(E360Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Live Now Strip
private struct HomeLiveStrip: View {
    let matches: [BackendMatchDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "home.liveNow",
                badge: "\(matches.count)",
                badgeColor: E360Color.live
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(matches, id: \.id) { match in
                        NavigationLink(destination: MatchDetailContainerView(matchID: match.id)) {
                            LiveMatchPill(match: match)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct LiveMatchPill: View {
    let match: BackendMatchDTO
    private var theme: Color { EsportsGame(backendCode: match.gameCode).themeColor }

    var body: some View {
        HStack(spacing: 10) {
            ESImageView(url: BackendURLResolver.resolveBackendURL(match.team1ImageUrl),
                        fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: match.team1Name ?? "")
                .frame(width: 28, height: 28).clipShape(Circle())

            VStack(spacing: 1) {
                Text("\(match.team1Score ?? 0) : \(match.team2Score ?? 0)")
                    .font(E360Font.mono(14, weight: .black)).foregroundStyle(E360Color.textPrimary)
                E360LivePulse(size: 4)
            }

            ESImageView(url: BackendURLResolver.resolveBackendURL(match.team2ImageUrl),
                        fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: match.team2Name ?? "")
                .frame(width: 28, height: 28).clipShape(Circle())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(E360Color.surface, in: Capsule())
        .overlay(Capsule().stroke(E360Color.live.opacity(0.30), lineWidth: 1))
        .shadow(color: E360Color.live.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Game Filter Chips
private struct HomeGameFilter: View {
    let games: [EsportsGame]
    @Binding var selected: EsportsGame?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All chip
                gameChip(title: String(localized: "home.filter.all", defaultValue: "الكل"),
                         color: E360Color.accent, isSelected: selected == nil) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selected = nil }
                }
                ForEach(games, id: \.self) { game in
                    gameChip(title: game.shortName, color: game.themeColor, isSelected: selected == game) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            selected = (selected == game) ? nil : game
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func gameChip(title: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { HapticManager.shared.triggerSelection(); action() }) {
            Text(title)
                .font(E360Font.rounded(12, weight: isSelected ? .black : .semibold))
                .foregroundStyle(isSelected ? .black : E360Color.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    isSelected ? color : E360Color.tintedSurface,
                    in: Capsule()
                )
                .overlay(Capsule().stroke(isSelected ? .clear : E360Color.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: - Match Feed
private struct HomeMatchFeed: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            E360SectionHeader(
                title: "home.today",
                subtitle: "home.today.subtitle",
                badge: viewModel.filteredMatches.isEmpty ? nil : "\(viewModel.filteredMatches.count)"
            )
            .padding(.horizontal, 20)

            if viewModel.isLoading {
                VStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonRow(height: 108, cornerRadius: 22)
                    }
                }
                .padding(.horizontal, 16)
            } else if let error = viewModel.error {
                HomeErrorBanner(message: error) {
                    Task { await viewModel.refresh() }
                }
                .padding(.horizontal, 16)
            } else if viewModel.filteredMatches.isEmpty {
                HomeEmptyState()
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredMatches, id: \.id) { match in
                        NavigationLink(destination: MatchDetailContainerView(matchID: match.id)) {
                            HomeMatchRow(match: match)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Match Row Card
struct HomeMatchRow: View {
    let match: BackendMatchDTO
    private var game: EsportsGame { EsportsGame(backendCode: match.gameCode) }
    private var theme: Color { game.themeColor }
    private var isLive: Bool { match.status == "running" }

    var body: some View {
        HStack(spacing: 14) {
            // Team 1
            matchTeam(
                name: match.team1Name,
                url: BackendURLResolver.resolveBackendURL(match.team1ImageUrl),
                score: match.team1Score,
                align: .trailing
            )

            // Center info
            VStack(spacing: 6) {
                if isLive {
                    HStack(spacing: 4) {
                        E360LivePulse(size: 5)
                        Text(String(localized: "match.live", defaultValue: "مباشر"))
                            .font(E360Font.mono(9, weight: .black))
                            .foregroundStyle(E360Color.live)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(E360Color.liveGlow, in: Capsule())
                } else if let t = match.scheduledAt {
                    Text(t, style: .time)
                        .font(E360Font.mono(12, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                }
                E360Badge(text: game.shortName, color: theme, size: 8)
            }
            .frame(width: 80)

            // Team 2
            matchTeam(
                name: match.team2Name,
                url: BackendURLResolver.resolveBackendURL(match.team2ImageUrl),
                score: match.team2Score,
                align: .leading
            )
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .e360MatchCard(themeColor: theme)
    }

    @ViewBuilder
    private func matchTeam(name: String?, url: URL?, score: Int?, align: HorizontalAlignment) -> some View {
        HStack(spacing: 10) {
            if align == .trailing {
                VStack(alignment: .trailing, spacing: 4) { teamInfo(name: name, score: score, align: .trailing) }
                ESImageView(url: url, fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: name ?? "")
                    .frame(width: 40, height: 40).clipShape(Circle())
            } else {
                ESImageView(url: url, fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: name ?? "")
                    .frame(width: 40, height: 40).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) { teamInfo(name: name, score: score, align: .leading) }
            }
        }
        .frame(maxWidth: .infinity, alignment: align == .trailing ? .trailing : .leading)
    }

    @ViewBuilder
    private func teamInfo(name: String?, score: Int?, align: HorizontalAlignment) -> some View {
        Text(name ?? "-")
            .font(E360Font.body(12, weight: .bold))
            .foregroundStyle(E360Color.textPrimary)
            .lineLimit(2).multilineTextAlignment(align == .trailing ? .trailing : .leading)
            .frame(maxWidth: 80)
        if let score {
            Text("\(score)")
                .font(E360Font.number(18, weight: .black))
                .foregroundStyle(isLive ? E360Color.live : E360Color.textPrimary)
        }
    }
}

// MARK: - Error & Empty
private struct HomeErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(E360Color.warning)
            Text(message)
                .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                .lineLimit(2)
            Spacer()
            Button(action: retry) {
                Text(String(localized: "common.retry", defaultValue: "إعادة"))
                    .font(E360Font.body(12, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(E360Color.primary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 18, tintColor: E360Color.warning)
    }
}

private struct HomeEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40, weight: .light)).foregroundStyle(E360Color.textTertiary)
            Text(String(localized: "home.empty.title", defaultValue: "لا توجد مباريات اليوم"))
                .font(E360Font.body(15, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Text(String(localized: "home.empty.subtitle", defaultValue: "تحقق لاحقاً أو اسحب للتحديث"))
                .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 48)
    }
}
