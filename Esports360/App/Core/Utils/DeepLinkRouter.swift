import Combine
import Foundation

enum DeepLinkDestination: Identifiable, Equatable {
    case match(String)
    case team(String)
    case tournament(String)
    case player(String)

    var id: String {
        switch self {
        case .match(let id):
            "match-\(id)"
        case .team(let id):
            "team-\(id)"
        case .tournament(let id):
            "tournament-\(id)"
        case .player(let id):
            "player-\(id)"
        }
    }

    var path: String {
        switch self {
        case .match(let id):
            "/match/\(id)"
        case .team(let id):
            "/team/\(id)"
        case .tournament(let id):
            "/tournament/\(id)"
        case .player(let id):
            "/player/\(id)"
        }
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var destination: DeepLinkDestination?

    func open(_ url: URL) {
        destination = Self.destination(for: url)
    }

    static func universalURL(for destination: DeepLinkDestination) -> URL {
        URL(string: "https://esports360.app\(destination.path)")!
    }

    static func destination(for url: URL) -> DeepLinkDestination? {
        var pathComponents = url.pathComponents.filter { $0 != "/" }

        if url.scheme == "esports360", let host = url.host, host.isEmpty == false {
            pathComponents.insert(host, at: 0)
        }

        guard pathComponents.count >= 2 else {
            return nil
        }
        let id = pathComponents[1]

        switch pathComponents[0].lowercased() {
        case "match", "matches":
            return .match(id)
        case "team", "teams":
            return .team(id)
        case "tournament", "tournaments":
            return .tournament(id)
        case "player", "players":
            return .player(id)
        default:
            return nil
        }
    }
}
