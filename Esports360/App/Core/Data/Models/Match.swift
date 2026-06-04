import Foundation

enum MatchStatus: String, Codable {
    case upcoming
    case live
    case finished
    case cancelled
    case unknown

    var isLive: Bool { self == .live }
}

struct Match: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var game: EsportsGame
    var gameImageURL: URL?
    var status: MatchStatus
    var beginAt: Date?
    var endAt: Date?
    var tournament: Tournament?
    var teams: [Team]
    var scores: [String: Int]
    var bestOf: Int
    var streamURL: URL?
    var streams: [MatchStream]
    var liveState: MatchLiveState?
    var maps: [MatchMap]
    var teamCompositions: [String: [String]]

    var firstTeam: Team? { teams.first }
    var secondTeam: Team? { teams.dropFirst().first }

    func score(for team: Team) -> Int {
        scores[team.id, default: 0]
    }

    var isFeaturedSaudiMatch: Bool {
        teams.contains { team in
            ["Team Falcons", "Twisted Minds", "Nasr Esports"].contains(team.name)
        }
    }

    var displayGameImageURL: URL? { gameImageURL ?? game.logoURL }
}

struct MatchStream: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var provider: String
    var language: String?
    var url: URL
    var thumbnailURL: URL?
    var viewerCount: Int?
    var isLive: Bool
    var isOfficial: Bool

    var providerDisplayName: String {
        switch provider.lowercased() {
        case "twitch": "Twitch"
        case "youtube": "YouTube"
        default: provider.isEmpty ? "Stream" : provider.capitalized
        }
    }

    var openURL: URL {
        guard provider.lowercased() == "twitch",
              let host = url.host(percentEncoded: false),
              host.contains("twitch.tv") else {
            return url
        }

        let channel = url.pathComponents.dropFirst().first
        guard let channel, channel.isEmpty == false else { return url }
        return URL(string: "twitch://stream/\(channel)") ?? url
    }
}

struct MatchLiveState: Codable, Hashable {
    var mapNumber: Int
    var roundNumber: Int?
    var clock: String?
    var phase: String

    var progress: Double {
        guard let roundNumber else { return 0 }
        return min(max(Double(roundNumber) / 24.0, 0), 1)
    }
}

struct MatchMap: Identifiable, Codable, Hashable {
    let id: String
    var number: Int
    var mapName: String?
    var status: String
    var startedAt: Date?
    var endedAt: Date?
    var durationSeconds: Int?
    var scores: [MatchMapScore]

    var isLive: Bool {
        ["live", "running", "in_progress"].contains(status.lowercased())
    }

    var isCompleted: Bool {
        ["completed", "finished"].contains(status.lowercased())
    }

    var isScheduled: Bool {
        ["scheduled", "upcoming"].contains(status.lowercased())
    }
}

struct MatchMapScore: Identifiable, Codable, Hashable {
    var teamID: String
    var totalRounds: Int
    var firstHalfRounds: Int?
    var secondHalfRounds: Int?
    var overtimeRounds: Int?
    var currentSide: String?

    var id: String { teamID }
}
