import Foundation
import OSLog
import Combine
import Network
import SwiftUI

// MARK: - HomeViewModel — Phase-3
// Added: isOffline state via NWPathMonitor, clearError()
@MainActor
final class HomeViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.esports360", category: "HomeViewModel")

    // ── Published state
    @Published private(set) var liveMatches:     [BackendMatchDTO] = []
    @Published private(set) var upcomingMatches: [BackendMatchDTO] = []
    @Published private(set) var recentMatches:   [BackendMatchDTO] = []
    @Published private(set) var availableGames:  [EsportsGame]    = []
    @Published private(set) var isLoading  = false
    @Published private(set) var isOffline  = false
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
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.esports360.network")

    init(repository: MatchRepositoryProtocol) {
        self.repository = repository
        startNetworkMonitor()
    }

    // ── Public
    func initialLoad() async {
        guard !isLoading else { return }
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    func clearError() {
        error = nil
    }

    // ── Private
    private func load(forceRefresh: Bool) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        async let liveTask     = repository.liveMatches(forceRefresh: forceRefresh)
        async let upcomingTask = repository.upcomingMatches(limit: 20, forceRefresh: forceRefresh)
        async let recentTask   = repository.recentMatches(limit: 10, forceRefresh: forceRefresh)

        let l: [BackendMatchDTO]
        do {
            l = try await liveTask
        } catch {
            l = []
            self.error = error.localizedDescription
            Self.logger.error("HomeViewModel failed to load live matches: \(error)")
        }

        let u: [BackendMatchDTO]
        do {
            u = try await upcomingTask
        } catch {
            u = []
            self.error = error.localizedDescription
            Self.logger.error("HomeViewModel failed to load upcoming matches: \(error)")
        }

        let r: [BackendMatchDTO]
        do {
            r = try await recentTask
        } catch {
            r = []
            if self.error == nil {
                self.error = error.localizedDescription
            }
            Self.logger.error("HomeViewModel failed to load recent matches: \(error)")
        }

        self.liveMatches     = l
        self.upcomingMatches = u
        self.recentMatches   = r
        buildGameFilter(from: l + u + r)
    }

    private func buildGameFilter(from matches: [BackendMatchDTO]) {
        let games = Set(matches.map { EsportsGame(backendCode: $0.gameCode) }).subtracting([.unknown])
        availableGames = EsportsGame.allCases.filter { games.contains($0) && $0 != .unknown }
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    self?.isOffline = path.status != .satisfied
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit { monitor.cancel() }
}
