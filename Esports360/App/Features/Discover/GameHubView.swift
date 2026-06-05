import SwiftUI

// MARK: - GameHubView
struct GameHubView: View {
    let game: GameCatalogItem
    @StateObject private var viewModel = GameHubViewModel()
    @State private var selectedTab = 0

    var body: some View {
        let esportsGame = EsportsGame(rawValue: game.code) ?? .unknown
        let themeColor  = esportsGame.themeColor

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gameHeader(themeColor: themeColor)

                Picker("", selection: $selectedTab) {
                    Text(String(localized: "discover.hub.matches",     defaultValue: "المباريات")).tag(0)
                    Text(String(localized: "discover.hub.tournaments", defaultValue: "البطولات")).tag(1)
                    Text(String(localized: "discover.hub.teams",       defaultValue: "الفرق")).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                // Error banner
                if let err = viewModel.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(E360Color.gold)
                        Text(err)
                            .font(E360Font.body(12, weight: .semibold))
                            .foregroundStyle(E360Color.textSecondary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                            Task { await viewModel.load(code: game.code) }
                        }
                        .font(E360Font.body(11, weight: .black))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(E360Color.primary.opacity(0.82), in: Capsule())
                        .foregroundStyle(E360Color.textPrimary)
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(E360Color.gold.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 16)
                }

                Group {
                    switch selectedTab {
                    case 0: matchesTabContent(themeColor: themeColor)
                    case 1: tournamentsTabContent(themeColor: themeColor)
                    default: teamsTabContent(themeColor: themeColor)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(game.displayShortName)
        .task(id: game.code) {
            await viewModel.load(code: game.code)
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func gameHeader(themeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ESImageView(url: game.displayImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                    .frame(width: 64, height: 64)
                    .shadow(color: themeColor.opacity(0.3), radius: 10)
                Spacer()
                Text(game.displayShortName)
                    .font(E360Font.mono(12, weight: .bold)).foregroundStyle(themeColor)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(themeColor.opacity(0.12), in: Capsule())
            }
            Text(game.displayName)
                .font(E360Font.display(28, weight: .bold)).foregroundStyle(E360Color.textPrimary)
            if let genre = game.genre {
                Text(genre).font(E360Font.body(14, weight: .medium)).foregroundStyle(E360Color.textSecondary)
            }
        }
        .padding(20)
        .background {
            ZStack {
                E360Color.surface
                LinearGradient(colors: [themeColor.opacity(0.18), themeColor.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Matches Tab
    @ViewBuilder
    private func matchesTabContent(themeColor: Color) -> some View {
        if viewModel.isLoadingMatches {
            tabSkeleton()
        } else {
            let matches = viewModel.matches
            if matches.isEmpty {
                emptyStateView(
                    message: String(localized: "discover.hub.no_matches", defaultValue: "لا توجد مباريات متاحة حالياً"),
                    icon: "gamecontroller"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(matches, id: \.id) { match in
                        NavigationLink(destination: MatchDetailContainerView(matchID: match.id)) {
                            matchRow(match, themeColor: themeColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func matchRow(_ match: GameHubMatchDTO, themeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.name ?? "")
                    .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                Spacer()
                if match.status == "live" {
                    Text(String(localized: "match.live", defaultValue: "مباشر"))
                        .font(E360Font.body(11, weight: .bold)).foregroundStyle(E360Color.live)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(E360Color.live.opacity(0.12), in: Capsule())
                }
            }
            HStack {
                if let scheduledAt = match.scheduledAt {
                    Text(scheduledAt, style: .date)
                        .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                    Text(scheduledAt, style: .time)
                        .font(E360Font.mono(12, weight: .medium)).foregroundStyle(themeColor)
                }
                Spacer()
                if let bo = match.bestOf {
                    Text("BO\(bo)")
                        .font(E360Font.mono(11, weight: .bold)).foregroundStyle(E360Color.textSecondary)
                }
            }
        }
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(match.status == "live" ? E360Color.live.opacity(0.35) : E360Color.divider, lineWidth: 1))
    }

    // MARK: - Tournaments Tab
    @ViewBuilder
    private func tournamentsTabContent(themeColor: Color) -> some View {
        if viewModel.isLoadingTournaments {
            tabSkeleton()
        } else {
            let tournaments = viewModel.tournaments
            if tournaments.isEmpty {
                emptyStateView(
                    message: String(localized: "discover.hub.no_tournaments", defaultValue: "لا توجد بطولات متاحة حالياً"),
                    icon: "trophy"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(tournaments, id: \.id) { tournament in
                        NavigationLink(destination: TournamentDetailView(tournamentId: tournament.id)) {
                            tournamentRow(tournament, themeColor: themeColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tournamentRow(_ tournament: GameHubTournamentDTO, themeColor: Color) -> some View {
        HStack(spacing: 12) {
            ESImageView(url: viewModel.resolveURL(tournament.imageUrl), fallbackAsset: E360ImageAsset.gamePlaceholder)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.name ?? "")
                    .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
                HStack {
                    if let start = tournament.beginAt {
                        Text(start, style: .date)
                            .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                    }
                    Spacer()
                    if tournament.status == "running" {
                        Text(String(localized: "match.live", defaultValue: "مباشر"))
                            .font(E360Font.body(11, weight: .bold)).foregroundStyle(themeColor)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(themeColor.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(E360Color.divider, lineWidth: 1))
    }

    // MARK: - Teams Tab
    @ViewBuilder
    private func teamsTabContent(themeColor: Color) -> some View {
        if viewModel.isLoadingTeams {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in SkeletonRow(height: 130, cornerRadius: 14) }
            }
        } else {
            let teams = viewModel.teams
            if teams.isEmpty {
                emptyStateView(
                    message: String(localized: "discover.hub.no_teams", defaultValue: "لا توجد فرق مسجّلة حالياً"),
                    icon: "person.3"
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(teams, id: \.id) { team in
                        VStack(spacing: 12) {
                            NavigationLink(destination: UnifiedTeamDetailView(teamId: team.id)) {
                                VStack(spacing: 12) {
                                    ESImageView(url: viewModel.resolveURL(team.imageUrl),
                                        fallbackAsset: E360ImageAsset.teamPlaceholder,
                                        fallbackText: team.name)
                                        .frame(width: 56, height: 56).clipShape(Circle())
                                    Text(team.name)
                                        .font(E360Font.body(14, weight: .bold))
                                        .foregroundStyle(E360Color.textPrimary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            DiscoverFollowButton(teamId: team.id, teamName: team.name, themeColor: themeColor)
                        }
                        .padding(14).frame(maxWidth: .infinity)
                        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeColor.opacity(0.15), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Shared Helpers
    @ViewBuilder
    private func tabSkeleton() -> some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in SkeletonRow(height: 72, cornerRadius: 14) }
        }
    }

    @ViewBuilder
    private func emptyStateView(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(E360Color.textSecondary)
            Text(message).font(E360Font.body(14, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// MARK: - ViewModel
@MainActor
private final class GameHubViewModel: ObservableObject {
    @Published private(set) var matches:     [GameHubMatchDTO]      = []
    @Published private(set) var tournaments: [GameHubTournamentDTO] = []
    @Published private(set) var teams:       [GameHubTeamDTO]       = []

    @Published private(set) var isLoadingMatches:     Bool = false
    @Published private(set) var isLoadingTournaments: Bool = false
    @Published private(set) var isLoadingTeams:       Bool = false
    @Published private(set) var errorMessage: String?

    private let apiClient = RepositoryFactory.makeAPIClient()

    func load(code: String) async {
        errorMessage = nil
        async let m = loadMatches(code: code)
        async let t = loadTournaments(code: code)
        async let tm = loadTeams(code: code)
        await m; await t; await tm
    }

    private func loadMatches(code: String) async {
        isLoadingMatches = true
        defer { isLoadingMatches = false }
        do    { matches = (try await apiClient.gameHub(code: code)).matches }
        catch { errorMessage = error.localizedDescription }
    }

    private func loadTournaments(code: String) async {
        isLoadingTournaments = true
        defer { isLoadingTournaments = false }
        do    { tournaments = (try await apiClient.gameHub(code: code)).tournaments }
        catch { errorMessage = error.localizedDescription }
    }

    private func loadTeams(code: String) async {
        isLoadingTeams = true
        defer { isLoadingTeams = false }
        do    { teams = (try await apiClient.gameHub(code: code)).teams }
        catch { errorMessage = error.localizedDescription }
    }

    nonisolated func resolveURL(_ rawString: String?) -> URL? {
        BackendURLResolver.resolveBackendURL(rawString)
    }
}
