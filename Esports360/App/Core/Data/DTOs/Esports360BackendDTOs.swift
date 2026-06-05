import Foundation

struct BackendListResponse<T: Decodable>: Decodable {
    let data: [T]
    let meta: BackendResponseMetaDTO?
}

struct BackendItemResponse<T: Decodable>: Decodable {
    let data: T
}

struct BackendResponseMetaDTO: Decodable {
    let filter: String?
    let timezone: String?
    let generatedAt: String?
    let total: Int?
    let returned: Int?
    let offset: Int?
}

struct BackendMatchDTO: Decodable {
    let id: String
    let name: String?
    let status: String?
    let scheduledAt: Date?
    let beginAt: Date?
    let endAt: Date?
    let bestOf: Int?
    let game: BackendGameDTO?
    let tournament: BackendTournamentDTO?
    let teams: [BackendMatchTeamDTO]?
    let liveState: BackendMatchLiveStateDTO?
    let games: [BackendMatchGameDTO]?
    let streams: [BackendMatchStreamDTO]?
}

struct BackendGameDTO: Decodable {
    let id: String
    let code: String?
    let name: String?
    let shortName: String?
    let genre: String?
    let publisher: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, code, name, shortName, genre, publisher
        case imageUrl = "imageUrl"
    }
}

struct BackendImageVariantDTO: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
    let format: String?
}

struct BackendImageDTO: Decodable {
    let sourceUrl: String?
    let variants: [String: BackendImageVariantDTO]?

    var preferredURL: String? {
        variants?["sm"]?.url
        ?? variants?["md"]?.url
        ?? variants?["lg"]?.url
        ?? variants?["xs"]?.url
        ?? sourceUrl
    }
}

struct BackendTournamentDTO: Decodable {
    let id: String
    let name: String?
    let leagueName: String?
    let seriesName: String?
    let beginAt: Date?
    let endAt: Date?
    let imageUrl: String?
    let gameImageUrl: String?
    let gameCode: String?
    let gameName: String?
    let gameShortName: String?
    let status: String?
    let prizePool: String?
    let prizeNote: String?
    let format: String?
    let tier: String?
    let location: String?
    let gameSummary: String?
    let matchCount: Int?
    let participantCount: Int?
    let isFeatured: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, leagueName, seriesName, beginAt, endAt, gameCode, gameName, gameShortName, status
        case gameImageUrl, prizePool, prizeNote, format, tier, location, gameSummary, matchCount, participantCount, isFeatured
        case imageUrl = "imageUrl"
        case image = "image"
        case startsAt = "startsAt"
        case endsAt = "endsAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        leagueName = try container.decodeIfPresent(String.self, forKey: .leagueName)
        seriesName = try container.decodeIfPresent(String.self, forKey: .seriesName)
        
        // Support startsAt/beginAt and endsAt/endAt
        beginAt = try container.decodeIfPresent(Date.self, forKey: .beginAt) ?? container.decodeIfPresent(Date.self, forKey: .startsAt)
        endAt = try container.decodeIfPresent(Date.self, forKey: .endAt) ?? container.decodeIfPresent(Date.self, forKey: .endsAt)
        
        // Handle "image" object or direct "imageUrl"
        if let img = try container.decodeIfPresent(String.self, forKey: .imageUrl) {
            imageUrl = img
        } else if let imageString = try? container.decodeIfPresent(String.self, forKey: .image) {
            imageUrl = imageString
        } else {
            let imageObject = try? container.decodeIfPresent(BackendImageDTO.self, forKey: .image)
            imageUrl = imageObject?.preferredURL
        }
        
        gameImageUrl = try container.decodeIfPresent(String.self, forKey: .gameImageUrl)
        gameCode = try container.decodeIfPresent(String.self, forKey: .gameCode)
        gameName = try container.decodeIfPresent(String.self, forKey: .gameName)
        gameShortName = try container.decodeIfPresent(String.self, forKey: .gameShortName)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        prizePool = try container.decodeIfPresent(String.self, forKey: .prizePool)
        prizeNote = try container.decodeIfPresent(String.self, forKey: .prizeNote)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        gameSummary = try container.decodeIfPresent(String.self, forKey: .gameSummary)
        matchCount = try container.decodeIfPresent(Int.self, forKey: .matchCount)
        participantCount = try container.decodeIfPresent(Int.self, forKey: .participantCount)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured)
    }
}

struct BackendMatchTeamDTO: Decodable {
    let id: String
    let name: String
    let acronym: String?
    let countryCode: String?
    let score: Int?
    let result: String?
    let side: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, acronym, countryCode, score, result, side
        case imageUrl = "imageUrl"
    }
}

struct BackendMatchLiveStateDTO: Decodable {
    let mapNumber: Int?
    let roundNumber: Int?
    let clock: String?
    let phase: String?
}

struct BackendMatchGameDTO: Decodable {
    let id: String
    let number: Int?
    let mapName: String?
    let status: String?
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Int?
    let scores: [BackendMatchGameScoreDTO]?

    enum CodingKeys: String, CodingKey {
        case id, number, mapName, status, startedAt, endedAt, durationSeconds, scores
        case map_name, game_number, started_at, ended_at, duration_seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
            ?? container.decodeIfPresent(Int.self, forKey: .game_number)
        mapName = try container.decodeIfPresent(String.self, forKey: .mapName)
            ?? container.decodeIfPresent(String.self, forKey: .map_name)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .started_at)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .ended_at)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
            ?? container.decodeIfPresent(Int.self, forKey: .duration_seconds)
        scores = try container.decodeIfPresent([BackendMatchGameScoreDTO].self, forKey: .scores)
    }
}

struct BackendMatchGameScoreDTO: Decodable {
    let teamId: String
    let totalRounds: Int?
    let firstHalfRounds: Int?
    let secondHalfRounds: Int?
    let overtimeRounds: Int?
    let currentSide: String?

    enum CodingKeys: String, CodingKey {
        case teamId, totalRounds, firstHalfRounds, secondHalfRounds, overtimeRounds, currentSide
        case team_id, total_rounds, first_half_rounds, second_half_rounds, overtime_rounds, current_side
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamId = try container.decodeIfPresent(String.self, forKey: .teamId)
            ?? container.decode(String.self, forKey: .team_id)
        totalRounds = try container.decodeIfPresent(Int.self, forKey: .totalRounds)
            ?? container.decodeIfPresent(Int.self, forKey: .total_rounds)
        firstHalfRounds = try container.decodeIfPresent(Int.self, forKey: .firstHalfRounds)
            ?? container.decodeIfPresent(Int.self, forKey: .first_half_rounds)
        secondHalfRounds = try container.decodeIfPresent(Int.self, forKey: .secondHalfRounds)
            ?? container.decodeIfPresent(Int.self, forKey: .second_half_rounds)
        overtimeRounds = try container.decodeIfPresent(Int.self, forKey: .overtimeRounds)
            ?? container.decodeIfPresent(Int.self, forKey: .overtime_rounds)
        currentSide = try container.decodeIfPresent(String.self, forKey: .currentSide)
            ?? container.decodeIfPresent(String.self, forKey: .current_side)
    }
}

struct BackendMatchStreamDTO: Decodable {
    let id: String
    let title: String?
    let provider: String?
    let language: String?
    let url: String
    let thumbnailUrl: String?
    let viewerCount: Int?
    let isLive: Bool?
    let official: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, provider, language, url, viewerCount, isLive, official
        case thumbnailUrl = "thumbnailUrl"
    }
}

struct BackendTeamDTO: Decodable {
    let id: String
    let name: String
    let shortName: String?
    let slug: String?
    let countryCode: String?
    let isSaudi: Bool?
    let imageUrl: String?
    let game: BackendGameDTO?
    let roster: [BackendRosterPlayerDTO]?
    let rosterCount: Int?
    let participatingGames: [BackendGameDTO]?

    enum CodingKeys: String, CodingKey {
        case id, name, shortName, slug, countryCode, isSaudi, game, roster, rosterCount, participatingGames
        case imageUrl = "imageUrl"
    }
}

struct BackendRosterPlayerDTO: Decodable {
    let id: String
    let handle: String
    let realName: String?
    let role: String?
    let isStarter: Bool?
    let imageUrl: String?
    let gameCode: String?
    let gameName: String?
    let gameShortName: String?
    let teamName: String?

    enum CodingKeys: String, CodingKey {
        case id, handle, realName, role, isStarter, gameCode, gameName, gameShortName, teamName
        case imageUrl = "imageUrl"
    }
}

extension BackendMatchDTO {
    var gameCode: String {
        game?.code ?? "unknown"
    }

    var team1Name: String? {
        teams?.first?.name
    }

    var team2Name: String? {
        (teams ?? []).count > 1 ? teams?[1].name : nil
    }

    var team1ImageUrl: String? {
        teams?.first?.imageUrl
    }

    var team2ImageUrl: String? {
        (teams ?? []).count > 1 ? teams?[1].imageUrl : nil
    }

    var team1Score: Int? {
        teams?.first?.score
    }

    var team2Score: Int? {
        (teams ?? []).count > 1 ? teams?[1].score : nil
    }

    var tournamentName: String? {
        tournament?.name
    }

    func toDomain(apiClient: Esports360APIClient) async -> Match {
        let domainTeams = (teams ?? []).map { dto in
            Team(
                id: dto.id,
                name: dto.name,
                acronym: dto.acronym,
                imageURL: apiClient.resolveMediaURL(dto.imageUrl),
                countryCode: dto.countryCode
            )
        }

        let scoreMap = Dictionary(uniqueKeysWithValues: (teams ?? []).map { ($0.id, $0.score ?? 0) })
        let gameCode = game?.code
        let domainGame = EsportsGame(backendCode: gameCode)
        let domainTournament = tournament.map {
            Tournament(
                id: $0.id,
                name: $0.name ?? "Tournament",
                leagueName: $0.leagueName,
                serieName: $0.seriesName,
                beginAt: $0.beginAt,
                endAt: $0.endAt,
                imageURL: apiClient.resolveMediaURL($0.imageUrl)
            )
        }

        let domainLiveState: MatchLiveState?
        if let liveState {
            domainLiveState = MatchLiveState(
                mapNumber: liveState.mapNumber ?? 1,
                roundNumber: liveState.roundNumber,
                clock: liveState.clock,
                phase: liveState.phase ?? "Live"
            )
        } else if status == "live" {
            domainLiveState = MatchLiveState(mapNumber: 1, roundNumber: nil, clock: nil, phase: "Live")
        } else {
            domainLiveState = nil
        }

        return Match(
            id: id,
            name: name ?? domainTeams.map(\.name).joined(separator: " vs "),
            game: domainGame,
            gameImageURL: apiClient.resolveMediaURL(game?.imageUrl),
            status: MatchStatus(backendStatus: status),
            beginAt: beginAt ?? scheduledAt,
            endAt: endAt,
            tournament: domainTournament,
            teams: domainTeams,
            scores: scoreMap,
            bestOf: bestOf ?? 1,
            streamURL: streams?.compactMap { URL(string: $0.url) }.first,
            streams: (streams ?? []).compactMap { dto in
                guard let url = URL(string: dto.url) else { return nil }
                return MatchStream(
                    id: dto.id,
                    title: dto.title ?? String(localized: "match.watchLive"),
                    provider: dto.provider ?? "stream",
                    language: dto.language,
                    url: url,
                    thumbnailURL: apiClient.resolveMediaURL(dto.thumbnailUrl),
                    viewerCount: dto.viewerCount,
                    isLive: dto.isLive ?? false,
                    isOfficial: dto.official ?? false
                )
            },
            liveState: domainLiveState,
            maps: (games ?? []).map { dto in
                MatchMap(
                    id: dto.id,
                    number: dto.number ?? 1,
                    mapName: dto.mapName,
                    status: dto.status ?? "scheduled",
                    startedAt: dto.startedAt,
                    endedAt: dto.endedAt,
                    durationSeconds: dto.durationSeconds,
                    scores: (dto.scores ?? []).map { score in
                        MatchMapScore(
                            teamID: score.teamId,
                            totalRounds: score.totalRounds ?? 0,
                            firstHalfRounds: score.firstHalfRounds,
                            secondHalfRounds: score.secondHalfRounds,
                            overtimeRounds: score.overtimeRounds,
                            currentSide: score.currentSide
                        )
                    }
                )
            },
            teamCompositions: [:]
        )
    }
}

extension BackendGameDTO {
    func toCatalogItem(apiClient: Esports360APIClient) -> GameCatalogItem {
        GameCatalogItem(
            id: id,
            code: code ?? "unknown",
            name: name ?? EsportsGame(backendCode: code).displayName,
            shortName: shortName,
            genre: genre,
            publisher: publisher,
            imageURL: apiClient.resolveMediaURL(imageUrl)
        )
    }
}

extension BackendTeamDTO {
    var gameName: String? { game?.name }
    var gameCode: String? { game?.code }

    func toTeam(apiClient: Esports360APIClient) -> Team {
        Team(
            id: id,
            name: name,
            acronym: shortName,
            imageURL: apiClient.resolveMediaURL(imageUrl),
            countryCode: countryCode
        )
    }

    func toProfile(apiClient: Esports360APIClient) -> TeamProfile {
        let team = toTeam(apiClient: apiClient)
        let resolvedGame = EsportsGame(backendCode: game?.code)
        let players = (roster ?? []).enumerated().map { index, player in
            PlayerProfile(
                id: player.id,
                handle: player.handle,
                realName: player.realName,
                role: player.role ?? String(localized: "team.player"),
                countryCode: nil,
                imageURL: apiClient.resolveMediaURL(player.imageUrl),
                kdRatio: 1.0 + (Double(index % 5) * 0.04),
                winRate: 60,
                matchesPlayed: 0,
                kdTrend: [
                    StatPoint(label: "M1", value: 0.98),
                    StatPoint(label: "M2", value: 1.02),
                    StatPoint(label: "M3", value: 1.0 + (Double(index % 4) * 0.04))
                ],
                pool: []
            )
        }

        return TeamProfile(
            id: id,
            team: team,
            game: resolvedGame,
            gameImageURL: apiClient.resolveMediaURL(game?.imageUrl),
            roster: players,
            recentResults: [],
            winRateHistory: [
                StatPoint(label: "W1", value: 54),
                StatPoint(label: "W2", value: 57),
                StatPoint(label: "W3", value: 61),
                StatPoint(label: "W4", value: 63),
                StatPoint(label: "W5", value: 60 + Double(players.count))
            ],
            form: [.win, .loss, .win, .win, .draw]
        )
    }
}

extension MatchStatus {
    init(backendStatus: String?) {
        switch backendStatus {
        case "live":
            self = .live
        case "scheduled", "pre_match", "postponed":
            self = .upcoming
        case "completed":
            self = .finished
        case "cancelled", "canceled", "forfeit":
            self = .cancelled
        default:
            self = .unknown
        }
    }
}

// MARK: - DISCOVER / EXPLORE PAGE DTOS

struct DiscoverTrendingDTO: Decodable {
    let tournaments: [BackendTournamentDTO]
    let teams: [BackendTeamDTO]
}

struct DiscoverSearchDTO: Decodable {
    let teams: [BackendTeamDTO]
    let tournaments: [BackendTournamentDTO]
    let players: [BackendPlayerDTO]
}

struct BackendPlayerDTO: Decodable {
    let id: String
    let handle: String
    let realName: String?
    let slug: String?
    let countryCode: String?
    let gameCode: String?
    let gameName: String?
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, handle, realName, slug, countryCode, gameCode, gameName
        case imageUrl = "imageUrl"
    }
}

typealias GameHubMatchDTO = BackendMatchDTO
typealias GameHubTournamentDTO = BackendTournamentDTO
typealias GameHubTeamDTO = BackendTeamDTO

struct GameHubDTO: Decodable {
    let game: BackendGameDTO
    let matches: [BackendMatchDTO]
    let teams: [BackendTeamDTO]
    let tournaments: [BackendTournamentDTO]
}

struct BackendTournamentMatchDTO: Decodable, Identifiable {
    let id: String
    let status: String?
    let scheduledAt: Date?
    let team1Name: String?
    let team2Name: String?
    let team1Score: Int?
    let team2Score: Int?

    enum CodingKeys: String, CodingKey {
        case id, status, scheduledAt, team1Name, team2Name, team1Score, team2Score
        case scheduled_at, team1_name, team2_name, team1_score, team2_score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
            ?? container.decodeIfPresent(Date.self, forKey: .scheduled_at)
        team1Name = try container.decodeIfPresent(String.self, forKey: .team1Name)
            ?? container.decodeIfPresent(String.self, forKey: .team1_name)
        team2Name = try container.decodeIfPresent(String.self, forKey: .team2Name)
            ?? container.decodeIfPresent(String.self, forKey: .team2_name)
        team1Score = try container.decodeIfPresent(Int.self, forKey: .team1Score)
            ?? container.decodeIfPresent(Int.self, forKey: .team1_score)
        team2Score = try container.decodeIfPresent(Int.self, forKey: .team2Score)
            ?? container.decodeIfPresent(Int.self, forKey: .team2_score)
    }
}

struct BackendTournamentTeamDTO: Decodable, Identifiable {
    let id: String
    let name: String?
    let acronym: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, acronym, imageUrl
        case image_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        acronym = try container.decodeIfPresent(String.self, forKey: .acronym)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            ?? container.decodeIfPresent(String.self, forKey: .image_url)
    }
}
