import Combine
import Foundation

// MARK: - DeepLinkDestination
enum DeepLinkDestination: Identifiable, Equatable {
    case match(String)
    case team(String)
    case tournament(String)
    case player(String)

    var id: String {
        switch self {
        case .match(let id):      "match-\(id)"
        case .team(let id):       "team-\(id)"
        case .tournament(let id): "tournament-\(id)"
        case .player(let id):     "player-\(id)"
        }
    }

    var path: String {
        switch self {
        case .match(let id):      "/match/\(id)"
        case .team(let id):       "/team/\(id)"
        case .tournament(let id): "/tournament/\(id)"
        case .player(let id):     "/player/\(id)"
        }
    }

    /// Convert to an AppRoute for in-app typed navigation
    var appRoute: AppRoute {
        switch self {
        case .match(let id):      .match(id: id)
        case .team(let id):       .team(id: id)
        case .tournament(let id): .tournament(id: id)
        case .player(let id):     .player(id: id)
        }
    }
}

// MARK: - DeepLinkRouter
@MainActor
final class DeepLinkRouter: ObservableObject {
    /// Set by AppRootView.onChange to push onto the active tab
    @Published var pendingRoute: AppRoute?

    func open(_ url: URL) {
        guard let dest = Self.destination(for: url) else { return }
        pendingRoute = dest.appRoute
    }

    // MARK: Universal URL helpers
    static func universalURL(for destination: DeepLinkDestination) -> URL {
        URL(string: "https://esports360.app\(destination.path)")!
    }

    static func universalURL(for route: AppRoute) -> URL {
        switch route {
        case .match(let id):            universalURL(for: .match(id))
        case .team(let id):             universalURL(for: .team(id))
        case .tournament(let id):       universalURL(for: .tournament(id))
        case .player(let id, _):        universalURL(for: .player(id))
        }
    }

    // MARK: URL parsing
    static func destination(for url: URL) -> DeepLinkDestination? {
        var components = url.pathComponents.filter { $0 != "/" }

        // Custom scheme: esports360://match/123
        if url.scheme == "esports360", let host = url.host, !host.isEmpty {
            components.insert(host, at: 0)
        }

        guard components.count >= 2 else { return nil }
        let id = components[1]

        switch components[0].lowercased() {
        case "match",      "matches":     return .match(id)
        case "team",       "teams":       return .team(id)
        case "tournament", "tournaments": return .tournament(id)
        case "player",     "players":     return .player(id)
        default: return nil
        }
    }
}
