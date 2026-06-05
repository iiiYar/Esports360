import SwiftUI
import Network

// MARK: - HomeView — Phase-3 Redesign
// ✔ Unified Design System: E360EmptyState / E360StatusBanner / E360SkeletonList / E360ChipGroup
// ✔ Offline detection + sticky banner
// ✔ NavigationStack removed (owned by AppRootView shell)
// ✔ AppRoute typed navigation via NavigationLink(value:)
// ✔ Pull-to-refresh preserved

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ZStack(alignment: .top) {
            E360Color.background.ignoresSafeArea()
            E360AmbientGlow()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // ── Hero Header
                    HomeHeroHeader(viewModel: viewModel)
                        .padding(.bottom, 22)

                    // ── Offline banner (inline, not sticky)
                    if viewModel.isOffline {
                        E360StatusBanner(style: .offline)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Error banner
                    if let err = viewModel.error, !viewModel.isLoading {
                        E360StatusBanner(style: .error(err), onDismiss: { viewModel.clearError() })
                            .padding(.horizontal, 18)
                            .padding(.bottom, 16)
                            .transition(.opacity)
                    }

                    // ── Live strip
                    if !viewModel.liveMatches.isEmpty {
                        HomeLiveStrip(matches: viewModel.liveMatches)
                            .padding(.bottom, 22)
                    }

                    // ── Game filter
                    HomeGameFilter(
                        games: viewModel.availableGames,
                        selected: $viewModel.selectedGameFilter
                    )
                    .padding(.bottom, 18)

                    // ── Match feed
                    HomeMatchFeed(viewModel: viewModel)
                        .padding(.bottom, 110) // tab bar clearance
                }
            }
            .refreshable { await viewModel.refresh() }
            .animation(.spring(response: 0.32, dampingFraction: 0.80), value: viewModel.isOffline)
            .animation(.easeOut(duration: 0.22), value: viewModel.error)
        }
        .task { await viewModel.initialLoad() }
    }
}

// MARK: - Hero Header
private struct HomeHeroHeader: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Title row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("home.greeting", defaultValue: "مرحباً ✨")
                        .font(E360Font.body(14, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                    Text("home.title", defaultValue: "الرياضة الإلكترونية")
                        .font(E360Font.display(28, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                }
                Spacer()

                // Live count badge
                if !viewModel.liveMatches.isEmpty {
                    HStack(spacing: 6) {
                        E360LivePulse(size: 6)
                        Text("\(viewModel.liveMatches.count) مباشر")
                            .font(E360Font.mono(11, weight: .bold))
                            .foregroundStyle(E360Color.live)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(E360Color.liveGlow, in: Capsule())
                    .overlay(Capsule().stroke(E360Color.live.opacity(0.30), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.30, dampingFraction: 0.75), value: viewModel.liveMatches.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Featured hero card
            Group {
                if viewModel.isLoading {
                    E360SkeletonView(type: .heroCard)
                        .padding(.horizontal, 16)
                } else if let featured = viewModel.featuredMatch {
                    NavigationLink(value: AppRoute.match(id: featured.id)) {
                        HomeFeaturedMatchCard(match: featured)
                    }
                    .buttonStyle(E360PressScale(scale: 0.97))
                    .padding(.horizontal, 16)
                }
            }
            .animation(.easeOut(duration: 0.24), value: viewModel.isLoading)
        }
    }
}

// MARK: - Featured Hero Card
struct HomeFeaturedMatchCard: View {
    let match: BackendMatchDTO

    private var game: EsportsGame  { EsportsGame(backendCode: match.gameCode) }
    private var theme: Color        { game.themeColor }
    private var isLive: Bool        { match.status == "running" }

    var body: some View {
        VStack(spacing: 0) {

            // Top strip
            HStack {
                E360Badge(text: game.shortName, color: theme)
                Spacer()
                if isLive {
                    HStack(spacing: 5) {
                        E360LivePulse(size: 5)
                        Text("مباشر الآن")
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

            // Teams
            HStack(spacing: 0) {
                teamSide(name: match.team1Name,
                         imageURL: BackendURLResolver.resolveBackendURL(match.team1ImageUrl),
                         score: match.team1Score,
                         align: .leading)
                E360VsSeparator().padding(.horizontal, 12)
                teamSide(name: match.team2Name,
                         imageURL: BackendURLResolver.resolveBackendURL(match.team2ImageUrl),
                         score: match.team2Score,
                         align: .trailing)
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
                .padding(.horizontal, 18).padding(.bottom, 14).padding(.top, 2)
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
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        isLive
                            ? LinearGradient(colors: [E360Color.live.opacity(0.50), E360Color.live.opacity(0.15)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [theme.opacity(0.35), E360Color.divider],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isLive ? 1.5 : 1.0
                    )
            }
        }
        .shadow(color: theme.opacity(isLive ? 0.22 : 0.08), radius: isLive ? 20 : 10, y: 8)
    }

    @ViewBuilder
    private func teamSide(name: String?, imageURL: URL?, score: Int?, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 8) {
            ESImageView(url: imageURL,
                        fallbackAsset: E360ImageAsset.teamPlaceholder,
                        fallbackText: name ?? "")
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .shadow(color: theme.opacity(0.25), radius: 8)

            Text(name ?? "-")
                .font(E360Font.body(13, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.8)
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

// MARK: - Live Strip
private struct HomeLiveStrip: View {
    let matches: [BackendMatchDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: "home.liveNow",
                icon: "dot.radiowaves.left.and.right",
                iconColor: E360Color.live,
                liveCount: matches.count
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(matches, id: \.id) { match in
                        NavigationLink(value: AppRoute.match(id: match.id)) {
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
                        fallbackAsset: E360ImageAsset.teamPlaceholder,
                        fallbackText: match.team1Name ?? "")
                .frame(width: 28, height: 28).clipShape(Circle())

            VStack(spacing: 2) {
                Text("\(match.team1Score ?? 0) : \(match.team2Score ?? 0)")
                    .font(E360Font.mono(14, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                E360LivePulse(size: 4)
            }

            ESImageView(url: BackendURLResolver.resolveBackendURL(match.team2ImageUrl),
                        fallbackAsset: E360ImageAsset.teamPlaceholder,
                        fallbackText: match.team2Name ?? "")
                .frame(width: 28, height: 28).clipShape(Circle())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(E360Color.surface, in: Capsule())
        .overlay(Capsule().stroke(E360Color.live.opacity(0.30), lineWidth: 1))
        .shadow(color: E360Color.live.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Game Filter — uses new E360ChipGroup
private struct HomeGameFilter: View {
    let games: [EsportsGame]
    @Binding var selected: EsportsGame?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" manual chip
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selected = nil }
                } label: {
                    Label("الكل", systemImage: "square.grid.2x2")
                        .font(E360Font.rounded(12, weight: selected == nil ? .black : .semibold))
                        .foregroundStyle(selected == nil ? .black : E360Color.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selected == nil ? E360Color.accent : E360Color.tintedSurface, in: Capsule())
                        .overlay(Capsule().stroke(selected == nil ? .clear : E360Color.divider, lineWidth: 1))
                }
                .buttonStyle(E360PressScale(scale: 0.94))
                .animation(.spring(response: 0.25, dampingFraction: 0.72), value: selected == nil)

                // Per-game chips
                ForEach(games, id: \.self) { game in
                    let isSel = selected == game
                    Button {
                        HapticManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            selected = isSel ? nil : game
                        }
                    } label: {
                        Text(game.shortName)
                            .font(E360Font.rounded(12, weight: isSel ? .black : .semibold))
                            .foregroundStyle(isSel ? .black : E360Color.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(isSel ? game.themeColor : E360Color.tintedSurface, in: Capsule())
                            .overlay(Capsule().stroke(isSel ? .clear : E360Color.divider, lineWidth: 1))
                    }
                    .buttonStyle(E360PressScale(scale: 0.94))
                    .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isSel)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Match Feed
private struct HomeMatchFeed: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            E360SectionHeader(
                title: "home.today",
                subtitle: "home.today.subtitle",
                badge: viewModel.filteredMatches.isEmpty ? nil : "\(viewModel.filteredMatches.count)",
                icon: "calendar",
                iconColor: E360Color.accent
            )
            .padding(.horizontal, 20)

            // ── Loading
            if viewModel.isLoading {
                E360SkeletonList(type: .matchCard, count: 5)
                    .padding(.horizontal, 16)

            // ── Empty
            } else if viewModel.filteredMatches.isEmpty {
                E360EmptyState(
                    style: viewModel.selectedGameFilter != nil
                        ? .noResults(query: viewModel.selectedGameFilter?.shortName ?? "")
                        : .noMatches,
                    onAction: viewModel.selectedGameFilter != nil
                        ? { withAnimation { viewModel.selectedGameFilter = nil } }
                        : nil,
                    actionLabel: viewModel.selectedGameFilter != nil
                        ? "عرض كل المباريات"
                        : nil
                )
                .padding(.horizontal, 16)

            // ── Content
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredMatches, id: \.id) { match in
                        NavigationLink(value: AppRoute.match(id: match.id)) {
                            HomeMatchRow(match: match)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.isLoading)
        .animation(.easeOut(duration: 0.22), value: viewModel.filteredMatches.count)
    }
}

// MARK: - Match Row Card
struct HomeMatchRow: View {
    let match: BackendMatchDTO
    private var game: EsportsGame  { EsportsGame(backendCode: match.gameCode) }
    private var theme: Color        { game.themeColor }
    private var isLive: Bool        { match.status == "running" }

    var body: some View {
        HStack(spacing: 14) {
            matchTeam(name: match.team1Name,
                      url: BackendURLResolver.resolveBackendURL(match.team1ImageUrl),
                      score: match.team1Score, align: .trailing)

            // Center
            VStack(spacing: 6) {
                if isLive {
                    HStack(spacing: 4) {
                        E360LivePulse(size: 5)
                        Text("مباشر")
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

            matchTeam(name: match.team2Name,
                      url: BackendURLResolver.resolveBackendURL(match.team2ImageUrl),
                      score: match.team2Score, align: .leading)
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
            .lineLimit(2)
            .multilineTextAlignment(align == .trailing ? .trailing : .leading)
            .frame(maxWidth: 80)
        if let score {
            Text("\(score)")
                .font(E360Font.number(18, weight: .black))
                .foregroundStyle(isLive ? E360Color.live : E360Color.textPrimary)
        }
    }
}
