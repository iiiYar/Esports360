import Foundation
import OSLog
import Combine

// MARK: - HomeViewModel — iOS 26 refresh
@MainActor
final class HomeViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.esports360", category: "HomeViewModel")

    // ── Published State
    @Published private(set) var liveMatches:     [BackendMatchDTO] = []
    @Published private(set) var upcomingMatches: [BackendMatchDTO] = []
    @Published private(set) var recentMatches:   [BackendMatchDTO] = []
    @Published private(set) var availableGames:  [EsportsGame]    = []
    @Published private(set) var isLoading  = false
    @Published private(set) var error: String? = nil
    @Published var selectedGameFilter: EsportsGame? = nil

    // ── Computed
    var featuredMatch: BackendMatchDTO? {
        liveMatches.first ?? upcomingMatches.first
    }

    var filteredMatches: [BackendMatchDTO] {
        let all = upcomingMatches + recentMatches
        guard let game = selectedGameFilter else { return all }
        return all.filter { EsportsGame(backendCode: $0.gameCode) == game }
    }

    // ── Dependencies
    private let repository: MatchRepositoryProtocol

    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
    }

    // ── Load
    func initialLoad() async {
        guard !isLoading else { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let live     = repository.liveMatches(forceRefresh: forceRefresh)
            async let upcoming = repository.upcomingMatches(limit: 20, forceRefresh: forceRefresh)
            async let recent   = repository.recentMatches(limit: 10, forceRefresh: forceRefresh)

            let (l, u, r) = try await (live, upcoming, recent)
            liveMatches     = l
            upcomingMatches = u
            recentMatches   = r
            buildGameFilter(from: l + u + r)
        } catch {
            self.error = error.localizedDescription
            Self.logger.error("HomeViewModel load failed: \(error)")
        }
    }

    private func buildGameFilter(from matches: [BackendMatchDTO]) {
        let games = Set(matches.map { EsportsGame(backendCode: $0.gameCode) }).subtracting([.unknown])
        availableGames = EsportsGame.allCases.filter { games.contains($0) && $0 != .unknown }
    }
}
