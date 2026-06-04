import Foundation

enum MatchOutcome: String, Codable, Hashable {
    case win = "W"
    case loss = "L"
    case draw = "D"

    var isPositive: Bool { self == .win }
}

struct StatPoint: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let value: Double

    init(label: String, value: Double) {
        self.id = label
        self.label = label
        self.value = value
    }
}

struct PlayerProfile: Identifiable, Codable, Hashable {
    let id: String
    let handle: String
    let realName: String?
    let role: String
    let countryCode: String?
    let imageURL: URL?
    let kdRatio: Double
    let winRate: Double
    let matchesPlayed: Int
    let kdTrend: [StatPoint]
    let pool: [String]
}

struct TeamMatchResult: Identifiable, Codable, Hashable {
    let id: String
    let opponent: Team
    let outcome: MatchOutcome
    let score: String
    let tournamentName: String
    let playedAt: Date
}

struct TeamProfile: Identifiable, Codable, Hashable {
    let id: String
    let team: Team
    let game: EsportsGame
    let gameImageURL: URL?
    let roster: [PlayerProfile]
    let recentResults: [TeamMatchResult]
    let winRateHistory: [StatPoint]
    let form: [MatchOutcome]

    var displayGameImageURL: URL? { gameImageURL ?? game.logoURL }
}

struct BracketMatch: Identifiable, Codable, Hashable {
    let id: String
    let firstTeam: Team
    let secondTeam: Team
    let firstScore: Int
    let secondScore: Int
    let winnerTeamID: String?
    let status: MatchStatus

    func score(for team: Team) -> Int {
        team.id == firstTeam.id ? firstScore : secondScore
    }

    func isWinner(_ team: Team) -> Bool {
        winnerTeamID == team.id
    }
}

struct BracketRound: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let matches: [BracketMatch]
}

struct GroupStanding: Identifiable, Codable, Hashable {
    let id: String
    let team: Team
    let points: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let mapDifferential: Int
}

struct TournamentBracket: Identifiable, Codable, Hashable {
    let id: String
    let tournament: Tournament
    let game: EsportsGame
    let rounds: [BracketRound]
    let standings: [GroupStanding]
}
