import Foundation

struct PandaScoreMatchDTO: Decodable {
    let id: Int
    let name: String?
    let status: String?
    let beginAt: Date?
    let endAt: Date?
    let numberOfGames: Int?
    let videogame: PandaScoreVideoGameDTO?
    let opponents: [PandaScoreOpponentEnvelopeDTO]?
    let results: [PandaScoreResultDTO]?
    let league: PandaScoreLeagueDTO?
    let serie: PandaScoreSerieDTO?
    let tournament: PandaScoreTournamentDTO?
    let streamsList: [PandaScoreStreamDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case beginAt = "begin_at"
        case endAt = "end_at"
        case numberOfGames = "number_of_games"
        case videogame
        case opponents
        case results
        case league
        case serie
        case tournament
        case streamsList = "streams_list"
    }
}

struct PandaScoreVideoGameDTO: Decodable {
    let id: Int?
    let name: String?
    let slug: String?
}

struct PandaScoreOpponentEnvelopeDTO: Decodable {
    let opponent: PandaScoreTeamDTO?
    let type: String?
}

struct PandaScoreTeamDTO: Decodable {
    let id: Int
    let name: String
    let acronym: String?
    let imageURL: URL?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case acronym
        case imageURL = "image_url"
        case location
    }
}

struct PandaScoreResultDTO: Decodable {
    let teamID: Int?
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case teamID = "team_id"
        case score
    }
}

struct PandaScoreLeagueDTO: Decodable {
    let id: Int?
    let name: String?
    let imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageURL = "image_url"
    }
}

struct PandaScoreSerieDTO: Decodable {
    let id: Int?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

struct PandaScoreTournamentDTO: Decodable {
    let id: Int?
    let name: String?
    let beginAt: Date?
    let endAt: Date?
    let imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case beginAt = "begin_at"
        case endAt = "end_at"
        case imageURL = "image_url"
    }
}

struct PandaScoreStreamDTO: Decodable {
    let rawURL: String?
    let language: String?
    let official: Bool?

    enum CodingKeys: String, CodingKey {
        case rawURL = "raw_url"
        case language
        case official
    }
}

extension PandaScoreMatchDTO {
    func toDomain() -> Match {
        let teams = opponents?
            .compactMap(\.opponent)
            .map { dto in
                Team(
                    id: String(dto.id),
                    name: dto.name,
                    acronym: dto.acronym,
                    imageURL: dto.imageURL,
                    countryCode: dto.location
                )
            } ?? []

        let scores: [String: Int] = Dictionary(
            uniqueKeysWithValues: (results ?? []).compactMap { result in
                guard let teamID = result.teamID else { return nil }
                return (String(teamID), result.score ?? 0)
            }
        )

        let domainTournament = Tournament(
            id: String(tournament?.id ?? league?.id ?? id),
            name: tournament?.name ?? league?.name ?? "Tournament",
            leagueName: league?.name,
            serieName: serie?.fullName,
            beginAt: tournament?.beginAt,
            endAt: tournament?.endAt,
            imageURL: tournament?.imageURL ?? league?.imageURL
        )

        let streamURL = streamsList?
            .first(where: { $0.official == true })?
            .rawURL
            .flatMap(URL.init(string:))

        let liveState = status == "running" ? MatchLiveState(
            mapNumber: 1,
            roundNumber: nil,
            clock: nil,
            phase: "Live"
        ) : nil

        return Match(
            id: String(id),
            name: name ?? teams.map(\.name).joined(separator: " vs "),
            game: EsportsGame(rawValue: videogame?.slug ?? "") ?? .unknown,
            gameImageURL: nil,
            status: MatchStatus(pandaScoreStatus: status),
            beginAt: beginAt,
            endAt: endAt,
            tournament: domainTournament,
            teams: teams,
            scores: scores,
            bestOf: numberOfGames ?? 1,
            streamURL: streamURL,
            streams: (streamsList ?? []).compactMap { stream in
                guard let rawURL = stream.rawURL, let url = URL(string: rawURL) else { return nil }
                return MatchStream(
                    id: rawURL,
                    title: stream.official == true ? String(localized: "match.officialStream") : String(localized: "match.watchLive"),
                    provider: url.host(percentEncoded: false)?.contains("twitch") == true ? "twitch" : "stream",
                    language: stream.language,
                    url: url,
                    thumbnailURL: nil,
                    viewerCount: nil,
                    isLive: status == "running",
                    isOfficial: stream.official ?? false
                )
            },
            liveState: liveState,
            maps: [],
            teamCompositions: [:]
        )
    }
}

extension MatchStatus {
    init(pandaScoreStatus: String?) {
        switch pandaScoreStatus {
        case "running":
            self = .live
        case "not_started":
            self = .upcoming
        case "finished":
            self = .finished
        case "canceled", "cancelled":
            self = .cancelled
        default:
            self = .unknown
        }
    }
}
