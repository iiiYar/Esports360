import SwiftUI

struct UnifiedTeamDetailView: View {
    let teamId: String
    
    @State private var teamDTO: BackendTeamDTO? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private let apiClient = RepositoryFactory.makeAPIClient()
    private let gridColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    SkeletonRow(height: 160, cornerRadius: 18)
                    SkeletonRow(height: 50, cornerRadius: 10)
                    SkeletonRow(height: 220, cornerRadius: 18)
                    Spacer()
                }
                .padding()
                .background(E360Color.background.ignoresSafeArea())
                .onAppear {
                    loadTeamDetails()
                }
            } else if let team = teamDTO {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 1. Unified Team Brand Header
                        VStack(spacing: 16) {
                            ZStack {
                                // Outer glowing brand ring
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [E360Color.primary, E360Color.accent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 104, height: 104)
                                    .shadow(color: E360Color.primary.opacity(0.35), radius: 10)
                                
                                ESImageView(url: apiClient.resolveMediaURL(team.imageUrl), fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: team.shortName ?? team.name)
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            }
                            
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(team.name)
                                        .font(E360Font.display(24, weight: .black))
                                        .foregroundStyle(E360Color.textPrimary)
                                    
                                    if let country = team.countryCode {
                                        Text(countryEmoji(country))
                                            .font(.system(size: 22))
                                    }
                                }
                                
                                if let acronym = team.shortName {
                                    Text(acronym)
                                        .font(E360Font.mono(12, weight: .bold))
                                        .foregroundStyle(E360Color.textSecondary)
                                }
                            }
                            
                            // Follow status inside header
                            DiscoverFollowButton(teamId: team.id, teamName: team.name, themeColor: E360Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            ZStack {
                                E360Color.surface
                                LinearGradient(
                                    colors: [E360Color.primary.opacity(0.06), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(E360Color.divider, lineWidth: 1)
                        )
                        
                        // 2. Participating Games Catalog
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundStyle(E360Color.accent)
                                Text(String(localized: "team.participating_games", defaultValue: "الألعاب المشارك فيها النادي"))
                                    .font(E360Font.display(18, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                            }
                            
                            let games = getParticipatingGames(team: team)
                            
                            LazyVGrid(columns: gridColumns, spacing: 14) {
                                ForEach(games) { game in
                                    NavigationLink {
                                        TeamProfileView(profile: makeSpecificProfile(team: team, game: game))
                                    } label: {
                                        UnifiedGameCard(game: game)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        TeamRosterDirectorySection(
                            roster: team.roster ?? [],
                            apiClient: apiClient
                        )
                    }
                    .padding(18)
                    .padding(.bottom, 60)
                }
                .background(E360Color.background.ignoresSafeArea())
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(E360Color.live)
                    
                    Text(errorMessage ?? String(localized: "discover.error.loading", defaultValue: "حدث خطأ أثناء تحميل البيانات"))
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                    
                    Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                        loadTeamDetails()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(E360Color.background.ignoresSafeArea())
            }
        }
        .navigationTitle(teamDTO?.name ?? String(localized: "team.profile", defaultValue: "ملف النادي"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadTeamDetails() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let team = try await apiClient.team(id: teamId)
                await MainActor.run {
                    self.teamDTO = team
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getParticipatingGames(team: BackendTeamDTO) -> [GameCatalogItem] {
        if let backendGames = team.participatingGames, !backendGames.isEmpty {
            return backendGames.map { $0.toCatalogItem(apiClient: apiClient) }
        }

        if let primaryGame = team.game {
            return [primaryGame.toCatalogItem(apiClient: apiClient)]
        }

        return []
    }
    
    private func makeSpecificProfile(team: BackendTeamDTO, game: GameCatalogItem) -> TeamProfile {
        let esportsGame = EsportsGame(rawValue: game.code) ?? .unknown
        let domainTeam = team.toTeam(apiClient: apiClient)
        let roster = filteredRoster(team.roster ?? [], for: game)

        let players = roster.enumerated().map { _, player in
            PlayerProfile(
                id: player.id,
                handle: player.handle,
                realName: player.realName,
                role: player.role ?? String(localized: "team.player", defaultValue: "لاعب"),
                countryCode: team.countryCode,
                imageURL: apiClient.resolveMediaURL(player.imageUrl),
                kdRatio: 0,
                winRate: 0,
                matchesPlayed: 0,
                kdTrend: [],
                pool: []
            )
        }
        
        return TeamProfile(
            id: team.id,
            team: domainTeam,
            game: esportsGame,
            gameImageURL: game.displayImageURL ?? esportsGame.logoURL,
            roster: players,
            recentResults: [],
            winRateHistory: [],
            form: []
        )
    }

    private func filteredRoster(_ roster: [BackendRosterPlayerDTO], for game: GameCatalogItem) -> [BackendRosterPlayerDTO] {
        let targetCode = game.code.lowercased()
        let gameTaggedPlayers = roster.filter { player in
            guard let playerGameCode = player.gameCode?.lowercased(), playerGameCode.isEmpty == false else {
                return false
            }
            return playerGameCode == targetCode
        }

        if gameTaggedPlayers.isEmpty == false {
            return gameTaggedPlayers
        }

        return roster.filter { ($0.gameCode ?? "").isEmpty }
    }
    
    private func countryEmoji(_ countryCode: String) -> String {
        let base : UInt32 = 127397
        var s = ""
        for v in countryCode.uppercased().unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return s
    }
}

private struct TeamRosterDirectorySection: View {
    let roster: [BackendRosterPlayerDTO]
    let apiClient: Esports360APIClient

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(E360Color.primary)

                Text(String(localized: "team.roster", defaultValue: "قائمة الفريق"))
                    .font(E360Font.display(18, weight: .bold))
                    .foregroundStyle(E360Color.textPrimary)

                Spacer()

                Text(ArabicNumberFormatter.localized(roster.count))
                    .font(E360Font.number(12, weight: .black))
                    .foregroundStyle(E360Color.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(E360Color.surface, in: Capsule())
            }

            if roster.isEmpty {
                EmptySectionView(text: "team.emptyRoster")
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(roster, id: \.id) { player in
                        TeamRosterDirectoryCard(player: player, apiClient: apiClient)
                    }
                }
            }
        }
    }
}

private struct TeamRosterDirectoryCard: View {
    let player: BackendRosterPlayerDTO
    let apiClient: Esports360APIClient

    var body: some View {
        let gameCode = player.gameCode ?? "unknown"
        let themeColor = EsportsGame(backendCode: gameCode).themeColor

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ESImageView(
                    url: apiClient.resolveMediaURL(player.imageUrl),
                    fallbackAsset: E360ImageAsset.playerPlaceholder,
                    fallbackText: player.handle
                )
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(Circle().stroke(themeColor.opacity(0.34), lineWidth: 1))

                Spacer()

                if let gameLabel = player.gameShortName ?? player.gameName, gameLabel.isEmpty == false {
                    Text(gameLabel)
                        .font(E360Font.mono(9, weight: .black))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.12), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player.handle)
                    .font(E360Font.body(15, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(1)

                if let realName = player.realName, realName.isEmpty == false {
                    Text(realName)
                        .font(E360Font.body(11, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Text(player.role ?? String(localized: "team.player", defaultValue: "لاعب"))
                .font(E360Font.body(11, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1)

            if let teamName = player.teamName, teamName.isEmpty == false {
                Text(teamName)
                    .font(E360Font.body(10, weight: .semibold))
                    .foregroundStyle(E360Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .background {
            ZStack {
                E360Color.surface.opacity(0.94)
                LinearGradient(
                    colors: [themeColor.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(themeColor.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct UnifiedGameCard: View {
    let game: GameCatalogItem
    
    var body: some View {
        let esportsGame = EsportsGame(rawValue: game.code) ?? .unknown
        let themeColor = esportsGame.themeColor
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ESImageView(url: game.displayImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                    .frame(width: 38, height: 38)
                    .shadow(color: themeColor.opacity(0.2), radius: 6)
                
                Spacer()
                
                Image(systemName: "chevron.backward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.displayName)
                    .font(E360Font.display(14, weight: .bold))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 38, alignment: .topLeading)
                
                Text(game.displayShortName)
                    .font(E360Font.mono(9, weight: .bold))
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(themeColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                E360Color.surface
                LinearGradient(
                    colors: [themeColor.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
        .shadow(color: themeColor.opacity(0.04), radius: 8, y: 4)
    }
}
