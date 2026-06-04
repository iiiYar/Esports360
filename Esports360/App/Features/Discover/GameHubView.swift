import SwiftUI

struct GameHubView: View {
    let game: GameCatalogItem
    @StateObject private var viewModel = GameHubViewModel()
    @State private var selectedTab = 0 // 0: Matches, 1: Tournaments, 2: Teams
    
    var body: some View {
        let esportsGame = EsportsGame(rawValue: game.code) ?? .unknown
        let themeColor = esportsGame.themeColor
        
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Ambient Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ESImageView(url: game.displayImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                            .frame(width: 64, height: 64)
                            .shadow(color: themeColor.opacity(0.3), radius: 10)
                        
                        Spacer()
                        
                        Text(game.displayShortName)
                            .font(E360Font.mono(12, weight: .bold))
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeColor.opacity(0.12), in: Capsule())
                    }
                    
                    Text(game.displayName)
                        .font(E360Font.display(28, weight: .bold))
                        .foregroundStyle(E360Color.textPrimary)
                    
                    if let genre = game.genre {
                        Text(genre)
                            .font(E360Font.body(14, weight: .medium))
                            .foregroundStyle(E360Color.textSecondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        E360Color.surface
                        LinearGradient(
                            colors: [themeColor.opacity(0.18), themeColor.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .padding(.horizontal, 16)
                
                // Segmented Picker
                Picker("", selection: $selectedTab) {
                    Text("discover.hub.matches").tag(0)
                    Text("discover.hub.tournaments").tag(1)
                    Text("discover.hub.teams").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                // Dynamic Tab Content
                Group {
                    if viewModel.isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                                .tint(themeColor)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if selectedTab == 0 {
                        matchesTabContent(themeColor: themeColor)
                    } else if selectedTab == 1 {
                        tournamentsTabContent(themeColor: themeColor)
                    } else {
                        teamsTabContent(themeColor: themeColor)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(game.displayShortName)
        .task {
            await viewModel.load(code: game.code)
        }
    }
    
    // MARK: - Matches Tab
    @ViewBuilder
    private func matchesTabContent(themeColor: Color) -> some View {
        let matches = viewModel.hubDetails?.matches ?? []
        
        if matches.isEmpty {
            emptyStateView(message: "discover.hub.no_matches", icon: "gamecontroller")
        } else {
            VStack(spacing: 12) {
                ForEach(matches, id: \.id) { match in
                    NavigationLink(destination: MatchDetailContainerView(matchID: match.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(match.name ?? "")
                                    .font(E360Font.body(14, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                
                                Spacer()
                                
                                if match.status == "live" {
                                    Text("match.live")
                                        .font(E360Font.body(11, weight: .bold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.red.opacity(0.12), in: Capsule())
                                }
                            }
                            
                            HStack {
                                if let scheduledAt = match.scheduledAt {
                                    Text(scheduledAt, style: .date)
                                        .font(E360Font.body(12, weight: .medium))
                                        .foregroundStyle(E360Color.textSecondary)
                                    
                                    Text(scheduledAt, style: .time)
                                        .font(E360Font.mono(12, weight: .medium))
                                        .foregroundStyle(themeColor)
                                }
                                
                                Spacer()
                                
                                if let bo = match.bestOf {
                                    Text("BO\(bo)")
                                        .font(E360Font.mono(11, weight: .bold))
                                        .foregroundStyle(E360Color.textSecondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(match.status == "live" ? .red.opacity(0.3) : E360Color.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Tournaments Tab
    @ViewBuilder
    private func tournamentsTabContent(themeColor: Color) -> some View {
        let tournaments = viewModel.hubDetails?.tournaments ?? []
        
        if tournaments.isEmpty {
            emptyStateView(message: "discover.hub.no_tournaments", icon: "trophy")
        } else {
            VStack(spacing: 12) {
                ForEach(tournaments, id: \.id) { tournament in
                    NavigationLink(destination: TournamentDetailView(tournamentId: tournament.id)) {
                        HStack(spacing: 12) {
                            ESImageView(url: viewModel.resolveURL(tournament.imageUrl), fallbackAsset: E360ImageAsset.gamePlaceholder)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tournament.name ?? "")
                                    .font(E360Font.body(14, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                    .lineLimit(1)
                                
                                HStack {
                                    if let start = tournament.beginAt {
                                        Text(start, style: .date)
                                            .font(E360Font.body(12, weight: .medium))
                                            .foregroundStyle(E360Color.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if tournament.status == "running" {
                                        Text("tournament.status.running")
                                            .font(E360Font.body(11, weight: .bold))
                                            .foregroundStyle(themeColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(themeColor.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(E360Color.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Teams Tab
    @ViewBuilder
    private func teamsTabContent(themeColor: Color) -> some View {
        let teams = viewModel.hubDetails?.teams ?? []
        
        if teams.isEmpty {
            emptyStateView(message: "discover.hub.no_teams", icon: "person.3")
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(teams, id: \.id) { team in
                    VStack(spacing: 12) {
                        NavigationLink(destination: TeamProfileLoaderView(teamId: team.id)) {
                            VStack(spacing: 12) {
                                ESImageView(url: viewModel.resolveURL(team.imageUrl), fallbackAsset: E360ImageAsset.gamePlaceholder)
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                                
                                Text(team.name)
                                    .font(E360Font.body(14, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        DiscoverFollowButton(teamId: team.id, teamName: team.name, themeColor: themeColor)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(E360Color.divider, lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func emptyStateView(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(E360Color.textSecondary)
            
            Text(LocalizedStringKey(message))
                .font(E360Font.body(14, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

@MainActor
private final class GameHubViewModel: ObservableObject {
    @Published private(set) var hubDetails: GameHubDTO? = nil
    @Published private(set) var isLoading = false
    
    private let apiClient = RepositoryFactory.makeAPIClient()
    
    func load(code: String) async {
        isLoading = true
        do {
            let details = try await apiClient.gameHub(code: code)
            hubDetails = details
        } catch {
            print("GameHubViewModel: failed to load hub for \(code): \(error)")
        }
        isLoading = false
    }
    
    nonisolated func resolveURL(_ rawString: String?) -> URL? {
        BackendURLResolver.resolveBackendURL(rawString)
    }
}
