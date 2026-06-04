import Foundation

enum EsportsGame: String, CaseIterable, Codable, Identifiable {
    case leagueOfLegends = "league-of-legends"
    case counterStrike = "cs-go"
    case valorant
    case dota2 = "dota-2"
    case rocketLeague = "rocket-league"
    case overwatch
    case rainbowSix = "rainbow-6-siege"
    case eaSportsFC = "ea-sports-fc"
    case starcraft2 = "starcraft-2"
    case callOfDuty = "call-of-duty"
    case kingOfGlory = "king-of-glory"
    case wildRift = "wild-rift"
    case unknown

    var id: String { rawValue }

    var logoURL: URL? {
        let storedBaseURL = UserDefaults.standard.string(forKey: AppStorageKeys.backendBaseURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBaseURL = storedBaseURL?.isEmpty == false ? storedBaseURL! : E360Constants.defaultBackendBaseURL
        let resolvedCode: String
        switch self {
        case .leagueOfLegends: resolvedCode = "lol"
        case .counterStrike: resolvedCode = "cs2"
        case .rocketLeague: resolvedCode = "rocket-league"
        case .overwatch: resolvedCode = "overwatch-2"
        case .rainbowSix: resolvedCode = "rainbow-six-siege"
        case .eaSportsFC: resolvedCode = "ea-fc"
        case .starcraft2: resolvedCode = "starcraft-2"
        case .callOfDuty: resolvedCode = "cod-mw"
        case .kingOfGlory: resolvedCode = "kog"
        case .wildRift: resolvedCode = "wild-rift"
        default: resolvedCode = self.rawValue
        }
        return URL(string: "\(rawBaseURL)/media/game/\(resolvedCode)/logo/sm.svg")
    }

    var displayName: String {
        switch self {
        case .leagueOfLegends: "League of Legends"
        case .counterStrike: "Counter-Strike 2"
        case .valorant: "Valorant"
        case .dota2: "Dota 2"
        case .rocketLeague: "Rocket League"
        case .overwatch: "Overwatch"
        case .rainbowSix: "Rainbow Six Siege"
        case .eaSportsFC: "EA Sports FC"
        case .starcraft2: "StarCraft II"
        case .callOfDuty: "Call of Duty"
        case .kingOfGlory: "King of Glory"
        case .wildRift: "Wild Rift"
        case .unknown: "Esports"
        }
    }

    var shortName: String {
        switch self {
        case .leagueOfLegends: "LoL"
        case .counterStrike: "CS2"
        case .rocketLeague: "RL"
        case .rainbowSix: "R6"
        case .eaSportsFC: "FC"
        case .starcraft2: "SC2"
        case .callOfDuty: "COD"
        case .kingOfGlory: "KOG"
        case .wildRift: "WR"
        default: displayName
        }
    }

    init(backendCode: String?) {
        switch backendCode {
        case "lol", "league-of-legends":
            self = .leagueOfLegends
        case "cs2", "cs-go", "counter-strike":
            self = .counterStrike
        case "valorant":
            self = .valorant
        case "dota2", "dota-2":
            self = .dota2
        case "rocket-league", "rl":
            self = .rocketLeague
        case "overwatch-2", "overwatch", "ow":
            self = .overwatch
        case "rainbow-six-siege", "rainbow-6-siege", "r6-siege":
            self = .rainbowSix
        case "ea-fc", "ea-sports-fc", "fifa":
            self = .eaSportsFC
        case "starcraft-2", "starcraft-brood-war":
            self = .starcraft2
        case "cod-mw", "call-of-duty":
            self = .callOfDuty
        case "kog", "king-of-glory":
            self = .kingOfGlory
        case "wild-rift", "lol-wild-rift":
            self = .wildRift
        default:
            self = .unknown
        }
    }
}

struct GameCatalogItem: Identifiable, Codable, Hashable {
    let id: String
    let code: String
    let name: String
    let shortName: String?
    let genre: String?
    let publisher: String?
    let imageURL: URL?

    var game: EsportsGame { EsportsGame(backendCode: code) }
    var displayName: String { name.isEmpty ? game.displayName : name }
    var displayShortName: String { shortName?.isEmpty == false ? shortName ?? game.shortName : game.shortName }
    var displayImageURL: URL? { imageURL ?? game.logoURL }
}
