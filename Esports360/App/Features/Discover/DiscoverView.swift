import SwiftUI
import OSLog
import Network

// MARK: - DiscoverView — Phase-5
// ✔ NavigationStack removed — owned by AppRootView shell
// ✔ AppRoute typed navigation via NavigationLink(value:)
// ✔ E360StatusBanner replaces DiscoverLoadErrorBanner
// ✔ E360SkeletonList replaces hand-rolled SkeletonRow loops
// ✔ E360EmptyState replaces inline empty VStack
// ✔ NWPathMonitor in ViewModel (isOffline)
// ✔ E360SectionHeader v2 throughout search results

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        ZStack {
            E360Color.background.ignoresSafeArea()
            VStack {
                LinearGradient(
                    colors: [E360Color.primary.opacity(0.08), E360Color.accent.opacity(0.04), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 350).blur(radius: 20).ignoresSafeArea()
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    if viewModel.searchText.isEmpty == false {
                        searchResultsSection
                            .padding(.top, 12)
                    } else {
                        directorySection
                            .padding(.top, 12)
                    }
                }
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: String(localized: "discover.search_prompt",
                           defaultValue: "البحث عن الألعاب، الفرق، أو البطولات...")
        )
        .task(id: viewModel.searchText) {
            guard !viewModel.searchText.isEmpty else { viewModel.clearSearch(); return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await viewModel.performSearch()
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load(forceRefresh: true) }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: viewModel.isOffline)
        .animation(.easeOut(duration: 0.22), value: viewModel.loadError)
    }

    // MARK: ─ Directory
    @ViewBuilder
    private var directorySection: some View {
        // Header
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(String(localized: "discover.clubs.directory", defaultValue: "دليل الأندية العالمي"))
                    .font(E360Font.display(26, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                Text("ALL")
                    .font(E360Font.mono(9, weight: .bold)).foregroundStyle(E360Color.accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(E360Color.accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(E360Color.accent.opacity(0.35), lineWidth: 1))
            }
            Text(String(
                format: String(localized: "discover.clubs.directory_subtitle_count",
                               defaultValue: "%@ نادي في قاعدة البيانات"),
                ArabicNumberFormatter.localized(viewModel.allTeamsTotal)
            ))
            .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
        }
        .padding(.horizontal, 18)

        // Stats bar
        DiscoverTeamsStatsBar(
            total: viewModel.allTeamsTotal,
            loaded: viewModel.allTeams.count,
            saudiCount: viewModel.saudiTeamsCount,
            gamesCount: viewModel.coveredGamesCount,
            isLoadingMore: viewModel.isLoadingMoreTeams
        )
        .padding(.horizontal, 18)

        // Sort bar
        DiscoverSortBar(selectedSort: $viewModel.selectedSort)
            .padding(.horizontal, 18)

        // Offline banner
        if viewModel.isOffline {
            E360StatusBanner(style: .offline)
                .padding(.horizontal, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
        }

        // Error banner
        if let err = viewModel.loadError, !viewModel.isAllTeamsLoading {
            E360StatusBanner(style: .error(err), onDismiss: { viewModel.clearError() })
                .padding(.horizontal, 18)
                .transition(.opacity)
        }

        // Teams list
        if viewModel.isAllTeamsLoading {
            E360SkeletonList(type: .teamRow, count: 6)
                .padding(.horizontal, 18)
        } else if viewModel.allTeams.isEmpty {
            E360EmptyState(
                style: .noTeams,
                onAction: { Task { await viewModel.load(forceRefresh: true) } },
                actionLabel: "إعادة التحميل"
            )
            .padding(.horizontal, 18)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.sortedTeams, id: \.id) { team in
                    NavigationLink(value: AppRoute.team(id: team.id)) {
                        DiscoverTeamDirectoryCard(team: team)
                    }
                    .buttonStyle(E360PressScale())
                    .onAppear { viewModel.loadMoreTeamsIfNeeded(currentTeam: team) }
                }
                if viewModel.isLoadingMoreTeams {
                    ProgressView().tint(E360Color.accent)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
    }

    // MARK: ─ Search Results
    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                E360EmptyState(
                    style: .custom(
                        icon: "text.magnifyingglass",
                        title: String(localized: "discover.search.min_chars", defaultValue: "اكتب 3 أحرف على الأقل"),
                        subtitle: "",
                        iconColor: E360Color.textTertiary
                    )
                )
                .padding(.horizontal, 18)
            } else if viewModel.isSearching {
                E360SkeletonList(type: .teamRow, count: 4)
                    .padding(.horizontal, 18)
            } else if let results = viewModel.searchResults {
                let hasTeams       = !results.teams.isEmpty
                let hasTournaments = !results.tournaments.isEmpty
                let hasPlayers     = !results.players.isEmpty

                if !hasTeams && !hasTournaments && !hasPlayers {
                    E360EmptyState(
                        style: .noResults(query: viewModel.searchText),
                        onAction: { viewModel.clearSearch() },
                        actionLabel: "مسح البحث"
                    )
                    .padding(.horizontal, 18)
                } else {
                    if hasTeams {
                        searchSection(
                            title: String(localized: "discover.search.section.teams", defaultValue: "الفرق"),
                            icon: "shield.fill", iconColor: E360Color.primary,
                            count: results.teams.count
                        ) {
                            ForEach(results.teams, id: \.id) { team in
                                NavigationLink(value: AppRoute.team(id: team.id)) {
                                    searchRow(
                                        imageURL: viewModel.resolveURL(team.imageUrl),
                                        title: team.name, subtitle: team.gameName
                                    )
                                }
                                .buttonStyle(E360PressScale())
                            }
                        }
                    }
                    if hasTournaments {
                        searchSection(
                            title: String(localized: "discover.search.section.tournaments", defaultValue: "البطولات"),
                            icon: "trophy.fill", iconColor: E360Color.gold,
                            count: results.tournaments.count
                        ) {
                            ForEach(results.tournaments, id: \.id) { t in
                                NavigationLink(value: AppRoute.tournament(id: t.id)) {
                                    searchRow(
                                        imageURL: viewModel.resolveURL(t.imageUrl),
                                        title: t.name ?? "", subtitle: t.gameName,
                                        clipAsRoundedRect: true
                                    )
                                }
                                .buttonStyle(E360PressScale())
                            }
                        }
                    }
                    if hasPlayers {
                        searchSection(
                            title: String(localized: "discover.search.section.players", defaultValue: "اللاعبون"),
                            icon: "person.fill", iconColor: E360Color.accent,
                            count: results.players.count
                        ) {
                            ForEach(results.players, id: \.id) { p in
                                NavigationLink(value: AppRoute.player(id: p.id, gameCode: p.gameCode)) {
                                    searchRow(
                                        imageURL: viewModel.resolveURL(p.imageUrl),
                                        title: p.handle, subtitle: p.realName
                                    )
                                }
                                .buttonStyle(E360PressScale())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: ─ Search helpers
    private func searchSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            E360SectionHeader(
                title: LocalizedStringKey(title),
                badge: "\(count)",
                badgeColor: iconColor,
                icon: icon,
                iconColor: iconColor
            )
            .padding(.horizontal, 18)
            content()
        }
    }

    private func searchRow(imageURL: URL?, title: String, subtitle: String?,
                           clipAsRoundedRect: Bool = false) -> some View {
        HStack {
            ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                .frame(width: 40, height: 40)
                .clipShape(clipAsRoundedRect
                    ? AnyShape(RoundedRectangle(cornerRadius: 8))
                    : AnyShape(Circle()))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                if let sub = subtitle {
                    Text(sub).font(E360Font.body(11, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.backward")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(E360Color.textSecondary)
        }
        .padding(12)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .e360RowHighlight()
        .padding(.horizontal, 18)
    }
}

// MARK: - DiscoverViewModel
@MainActor
final class DiscoverViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.esports360", category: "DiscoverViewModel")

    @Published var searchText: String = ""
    @Published private(set) var searchResults:       DiscoverSearchDTO?
    @Published private(set) var isSearching          = false
    @Published private(set) var loadError:           String?
    @Published private(set) var isOffline            = false
    @Published private(set) var trendingTournaments: [BackendTournamentDTO] = []
    @Published private(set) var trendingTeams:       [BackendTeamDTO]       = []
    @Published private(set) var allTeams:            [BackendTeamDTO]       = []
    @Published private(set) var allTeamsTotal        = 0
    @Published private(set) var saudiTeamsCount      = 0
    @Published private(set) var coveredGamesCount    = 0
    @Published private(set) var isAllTeamsLoading    = false
    @Published private(set) var isLoadingMoreTeams   = false
    @Published var selectedSort: TeamDirectorySort   = .saudiFirst
    @Published private(set) var games: [GameCatalogItem] = EsportsGame.allCases
        .filter { $0 != .unknown }
        .map { GameCatalogItem(id: $0.id, code: $0.rawValue, name: $0.displayName,
                               shortName: $0.shortName, genre: nil, publisher: nil, imageURL: nil) }

    private let repository    = BackendCatalogRepository()
    private let apiClient     = RepositoryFactory.makeAPIClient()
    private let teamsPageSize = 50
    private let monitor       = NWPathMonitor()
    private let monitorQueue  = DispatchQueue(label: "com.esports360.network.discover")

    var sortedTeams: [BackendTeamDTO] {
        switch selectedSort {
        case .saudiFirst:
            allTeams.sorted {
                if ($0.isSaudi == true) != ($1.isSaudi == true) { return $0.isSaudi == true }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .name:
            allTeams.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .game:
            allTeams.sorted {
                let l = $0.game?.name ?? $0.participatingGames?.first?.name ?? ""
                let r = $1.game?.name ?? $1.participatingGames?.first?.name ?? ""
                return l != r ? l.localizedStandardCompare(r) == .orderedAscending
                              : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .importance: allTeams
        }
    }

    init() { startNetworkMonitor() }

    func load(forceRefresh: Bool = false) async {
        loadError = nil
        if forceRefresh {
            allTeams = []; allTeamsTotal = 0; isLoadingMoreTeams = false; updateTeamCounts()
        }
        do { let g = try await repository.games(); if !g.isEmpty { games = g } } catch {}
        do {
            let t = try await apiClient.discoverTrending()
            trendingTournaments = t.tournaments; trendingTeams = t.teams
        } catch { Self.logger.warning("trending failed: \(error)") }
        isAllTeamsLoading = true
        do {
            let res = try await apiClient.teams(limit: teamsPageSize, offset: 0, forceRefresh: forceRefresh)
            allTeams = res.data; allTeamsTotal = res.meta?.total ?? res.data.count; updateTeamCounts()
        } catch {
            loadError = error.localizedDescription
            Self.logger.error("load teams failed: \(error)")
        }
        isAllTeamsLoading = false
    }

    func loadMoreTeamsIfNeeded(currentTeam: BackendTeamDTO) {
        guard currentTeam.id == sortedTeams.last?.id else { return }
        Task { await loadMoreTeams() }
    }

    private func loadMoreTeams() async {
        guard !isAllTeamsLoading, !isLoadingMoreTeams, allTeams.count < allTeamsTotal else { return }
        isLoadingMoreTeams = true
        defer { isLoadingMoreTeams = false }
        do {
            let res = try await apiClient.teams(limit: teamsPageSize, offset: allTeams.count)
            let ids = Set(allTeams.map(\.id))
            allTeams.append(contentsOf: res.data.filter { !ids.contains($0.id) })
            allTeamsTotal = res.meta?.total ?? allTeamsTotal; updateTeamCounts()
        } catch {
            loadError = error.localizedDescription
            Self.logger.error("loadMore teams failed: \(error)")
        }
    }

    func performSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 3 else { searchResults = nil; isSearching = false; return }
        isSearching = true
        defer { isSearching = false }
        do { searchResults = try await apiClient.discoverSearch(query: q) }
        catch { Self.logger.warning("search failed: \(error)") }
    }

    func clearSearch() { searchText = ""; searchResults = nil; isSearching = false }
    func clearError()  { loadError = nil }

    nonisolated func resolveURL(_ raw: String?) -> URL? { BackendURLResolver.resolveBackendURL(raw) }

    private func updateTeamCounts() {
        saudiTeamsCount   = allTeams.filter { $0.isSaudi == true }.count
        coveredGamesCount = Set(allTeams.flatMap { team -> [String] in
            if let gs = team.participatingGames, !gs.isEmpty { return gs.compactMap(\.code) }
            return [team.gameCode].compactMap { $0 }
        }).count
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    self?.isOffline = path.status != .satisfied
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit { monitor.cancel() }
}

// MARK: - Premium UI Components (unchanged visuals)

private struct DiscoverTournamentCard: View {
    let tournament: BackendTournamentDTO
    @State private var isPulsing = false
    var body: some View {
        let esportsGame = EsportsGame(backendCode: tournament.gameCode)
        let themeColor  = esportsGame.themeColor
        let isLive      = tournament.status == "running"
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ESImageView(url: BackendURLResolver.resolveBackendURL(tournament.imageUrl),
                            fallbackAsset: E360ImageAsset.gamePlaceholder)
                    .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeColor.opacity(0.4), lineWidth: 1))
                Spacer()
                Text(esportsGame.shortName).font(E360Font.mono(9, weight: .bold)).foregroundStyle(themeColor)
                    .padding(.horizontal, 9).padding(.vertical, 5).background(themeColor.opacity(0.12), in: Capsule())
            }
            Text(tournament.name ?? "").font(E360Font.display(16, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading).frame(height: 48, alignment: .topLeading)
            HStack {
                if isLive {
                    HStack(spacing: 5) {
                        E360LivePulse(size: 6)
                        Text(String(localized: "match.live", defaultValue: "مباشر الآن"))
                            .font(E360Font.mono(10, weight: .bold)).foregroundStyle(E360Color.live)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(E360Color.live.opacity(0.12), in: Capsule())
                } else if let starts = tournament.beginAt {
                    Text(starts, style: .date).font(E360Font.body(11, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                }
                Spacer()
                Text(tournament.prizePool?.isEmpty == false ? tournament.prizePool! : "TBA")
                    .font(E360Font.number(11, weight: .bold)).foregroundStyle(E360Color.gold)
            }
        }
        .padding(16).frame(width: 220)
        .background(ZStack {
            E360Color.surface
            LinearGradient(colors: [themeColor.opacity(0.08), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        })
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(
            LinearGradient(colors: [themeColor.opacity(isLive ? 0.6 : 0.2), E360Color.divider],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: isLive ? 1.5 : 1.0))
        .shadow(color: themeColor.opacity(isLive ? 0.22 : 0.04), radius: isLive ? 14 : 8, y: isLive ? 8 : 4)
    }
}

private struct DiscoverTrendingTeamCard: View {
    let team: BackendTeamDTO
    var body: some View {
        let esportsGame = EsportsGame(backendCode: team.gameCode)
        let themeColor  = esportsGame.themeColor
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(
                    LinearGradient(colors: [themeColor, themeColor.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 2
                ).frame(width: 68, height: 68).shadow(color: themeColor.opacity(0.35), radius: 8)
                ESImageView(url: BackendURLResolver.resolveBackendURL(team.imageUrl),
                            fallbackAsset: E360ImageAsset.teamPlaceholder,
                            fallbackText: team.shortName ?? team.name)
                    .frame(width: 58, height: 58).clipShape(Circle())
            }
            .padding(.top, 4)
            VStack(spacing: 4) {
                Text(team.name).font(E360Font.display(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text(esportsGame.shortName).font(E360Font.mono(9, weight: .black)).foregroundStyle(themeColor)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(themeColor.opacity(0.1), in: Capsule())
            }
        }
        .padding(16).frame(width: 136)
        .background(ZStack {
            E360Color.surface
            LinearGradient(colors: [themeColor.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)
        })
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(
            LinearGradient(colors: [E360Color.divider, themeColor.opacity(0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.0))
        .shadow(color: themeColor.opacity(0.08), radius: 10, y: 5)
    }
}

// MARK: - Directory Helpers
enum TeamDirectorySort: String, CaseIterable, Identifiable {
    case saudiFirst, name, game, importance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .saudiFirst: String(localized: "discover.clubs.sort.saudi",      defaultValue: "السعودية أولاً")
        case .name:       String(localized: "discover.clubs.sort.name",       defaultValue: "حسب الاسم")
        case .game:       String(localized: "discover.clubs.sort.game",       defaultValue: "حسب اللعبة")
        case .importance: String(localized: "discover.clubs.sort.importance", defaultValue: "الأهمية")
        }
    }
}

private struct DiscoverSortBar: View {
    @Binding var selectedSort: TeamDirectorySort
    var body: some View {
        HStack {
            Text(String(localized: "discover.clubs.sort.title", defaultValue: "ترتيب الأندية"))
                .font(E360Font.body(12, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Spacer()
            Menu {
                ForEach(TeamDirectorySort.allCases) { sort in
                    Button { selectedSort = sort } label: {
                        Label(sort.title,
                              systemImage: selectedSort == sort ? "checkmark" : "arrow.up.arrow.down")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedSort.title).font(E360Font.body(12, weight: .black))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .black))
                }
                .foregroundStyle(E360Color.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(E360Color.surface, in: Capsule())
                .overlay(Capsule().stroke(E360Color.divider, lineWidth: 1))
            }
        }
    }
}

private struct DiscoverTeamsStatsBar: View {
    let total: Int; let loaded: Int; let saudiCount: Int
    let gamesCount: Int; let isLoadingMore: Bool
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                DiscoverStatPill(title: String(localized: "discover.clubs.stats.total",
                                              defaultValue: "الأندية"),
                                 value: ArabicNumberFormatter.localized(total),
                                 icon: "shield.fill", color: E360Color.primary)
                DiscoverStatPill(title: String(localized: "discover.clubs.stats.saudi",
                                              defaultValue: "السعودية"),
                                 value: ArabicNumberFormatter.localized(saudiCount),
                                 icon: "checkmark.seal.fill", color: E360Color.gold)
                DiscoverStatPill(title: String(localized: "discover.clubs.stats.games",
                                              defaultValue: "الألعاب"),
                                 value: ArabicNumberFormatter.localized(gamesCount),
                                 icon: "gamecontroller.fill", color: E360Color.accent)
            }
            if isLoadingMore, total > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(loaded), total: Double(total)).tint(E360Color.accent)
                    Text(String(
                        format: String(localized: "discover.clubs.loading_progress",
                                       defaultValue: "%@ من %@ معروضة"),
                        ArabicNumberFormatter.localized(loaded),
                        ArabicNumberFormatter.localized(total)
                    ))
                    .font(E360Font.mono(10, weight: .bold)).foregroundStyle(E360Color.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(E360Color.surface.opacity(0.72),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct DiscoverStatPill: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
                .frame(width: 22, height: 22).background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(E360Font.number(15, weight: .black)).foregroundStyle(E360Color.textPrimary)
                Text(title).font(E360Font.body(9, weight: .bold)).foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 54)
        .background(E360Color.surface.opacity(0.86),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.2), lineWidth: 1))
    }
}

private struct DiscoverTeamDirectoryCard: View {
    let team: BackendTeamDTO
    var body: some View {
        let games       = displayGames
        let esportsGame = EsportsGame(backendCode: games.first?.code ?? team.gameCode)
        let themeColor  = esportsGame.themeColor
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor.opacity(0.24), E360Color.elevatedSurface.opacity(0.9)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 78, height: 78)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(themeColor.opacity(0.34), lineWidth: 1))
                ESImageView(url: BackendURLResolver.resolveBackendURL(team.imageUrl),
                            fallbackAsset: E360ImageAsset.teamPlaceholder,
                            fallbackText: team.shortName ?? team.name)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let country = team.countryCode {
                    Text(countryEmoji(country)).font(.system(size: 15))
                        .padding(5).background(E360Color.background.opacity(0.9), in: Circle())
                        .overlay(Circle().stroke(E360Color.divider, lineWidth: 1))
                        .offset(x: 5, y: 5)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(team.name).font(E360Font.display(17, weight: .black))
                            .foregroundStyle(E360Color.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                        if let short = team.shortName, !short.isEmpty {
                            Text(short).font(E360Font.mono(10, weight: .bold))
                                .foregroundStyle(E360Color.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if team.isSaudi == true {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 9, weight: .bold))
                            Text(String(localized: "discover.clubs.saudi_badge", defaultValue: "سعودي"))
                                .font(E360Font.body(9, weight: .black))
                        }
                        .foregroundStyle(E360Color.gold)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(E360Color.gold.opacity(0.13), in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    MiniMetric(icon: "person.3.fill",
                               value: ArabicNumberFormatter.localized(team.rosterCount ?? 0),
                               title: String(localized: "discover.clubs.roster", defaultValue: "لاعب"))
                    MiniMetric(icon: "gamecontroller.fill",
                               value: ArabicNumberFormatter.localized(games.count),
                               title: String(localized: "discover.clubs.games", defaultValue: "لعبة"))
                }
                HStack(spacing: 6) {
                    if games.isEmpty {
                        GameChip(title: esportsGame.shortName, imageURL: nil, color: themeColor)
                    } else {
                        ForEach(Array(games.prefix(4)), id: \.id) { game in
                            GameChip(
                                title: game.shortName ?? game.name
                                    ?? EsportsGame(backendCode: game.code).shortName,
                                imageURL: BackendURLResolver.resolveBackendURL(game.imageUrl),
                                color: EsportsGame(backendCode: game.code).themeColor
                            )
                        }
                        if games.count > 4 {
                            GameChip(title: "+\(ArabicNumberFormatter.localized(games.count - 4))",
                                     imageURL: nil, color: E360Color.textSecondary)
                        }
                    }
                }
                .lineLimit(1)
            }
            Image(systemName: "chevron.backward")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(E360Color.textSecondary)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(ZStack {
            E360Color.surface.opacity(0.94)
            LinearGradient(colors: [themeColor.opacity(0.1), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        })
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(
            LinearGradient(colors: [themeColor.opacity(0.28), E360Color.divider],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.0))
        .shadow(color: themeColor.opacity(0.08), radius: 10, y: 5)
        .e360RowHighlight()
    }
    private var displayGames: [BackendGameDTO] {
        if let gs = team.participatingGames, !gs.isEmpty { return gs }
        if let g = team.game { return [g] }
        return []
    }
    private func countryEmoji(_ code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.reduce("") { $0 + String(UnicodeScalar(base + $1.value)!) }
    }
}

private struct MiniMetric: View {
    let icon: String; let value: String; let title: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Text(value).font(E360Font.number(11, weight: .black)).foregroundStyle(E360Color.textPrimary)
            Text(title).font(E360Font.body(10, weight: .medium)).foregroundStyle(E360Color.textSecondary)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(E360Color.background.opacity(0.48), in: Capsule())
    }
}

private struct GameChip: View {
    let title: String; let imageURL: URL?; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                .frame(width: 15, height: 15)
            Text(title).font(E360Font.mono(9, weight: .black)).foregroundStyle(color).lineLimit(1)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(color.opacity(0.11), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
    }
}
