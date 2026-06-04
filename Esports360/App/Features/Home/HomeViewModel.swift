import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum LiveConnectionState: Equatable {
        case disabled
        case connecting
        case connected(Int)
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var liveConnectionState: LiveConnectionState = .disabled
    @Published private(set) var liveMatches: [Match] = []
    @Published private(set) var upcomingMatches: [Match] = []
    @Published private(set) var completedMatches: [Match] = []
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var refreshErrorMessage: String?
    @Published private(set) var notificationMessage: String?
    @Published private(set) var newsTickerItems: [String] = [
        "ticker.ewc",
        "ticker.saudiTeams",
        "ticker.fantasy"
    ]

    private var repository: MatchRepository
    private let liveScoreStreamer: LiveScoreStreaming
    private let notificationService: NotificationService
    private var liveTasks: [Task<Void, Never>] = []
    private var loadGeneration = 0

    init(
        repository: MatchRepository,
        liveScoreStreamer: LiveScoreStreaming = LiveScoreWebSocketManager(),
        notificationService: NotificationService = NotificationService()
    ) {
        self.repository = repository
        self.liveScoreStreamer = liveScoreStreamer
        self.notificationService = notificationService
    }

    deinit {
        liveTasks.forEach { $0.cancel() }
    }

    func updateRepository(baseURL: String?) {
        repository = RepositoryFactory.makeMatchRepository(baseURL: baseURL)
    }

    #if DEBUG
    func replaceRepositoryForTesting(_ repository: MatchRepository) {
        self.repository = repository
    }
    #endif

    func load(forceRefresh: Bool = false) async {
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading

        do {
            let matches = try await repository.todaysMatches(forceRefresh: forceRefresh)
            guard generation == loadGeneration else { return }
            apply(matches: matches)
            lastUpdatedAt = Date()
            refreshErrorMessage = nil
            state = .loaded
        } catch {
            guard generation == loadGeneration else { return }
            refreshErrorMessage = String(localized: "home.refreshFailed")
            state = .failed(error.localizedDescription)
        }
    }

    private func apply(matches: [Match]) {
        liveMatches = matches
            .filter { $0.status == .live }
            .sorted { ($0.beginAt ?? .distantFuture) < ($1.beginAt ?? .distantFuture) }
        upcomingMatches = matches
            .filter { $0.status == .upcoming }
            .sorted { ($0.beginAt ?? .distantFuture) < ($1.beginAt ?? .distantFuture) }
        completedMatches = matches
            .filter { $0.status == .finished }
            .sorted { ($0.endAt ?? $0.beginAt ?? .distantPast) > ($1.endAt ?? $1.beginAt ?? .distantPast) }
    }

    func startLiveUpdates() {
        stopLiveUpdates()

        guard liveMatches.isEmpty == false else {
            liveConnectionState = .disabled
            return
        }

        liveConnectionState = .unavailable
    }

    func stopLiveUpdates() {
        liveTasks.forEach { $0.cancel() }
        liveTasks.removeAll()

        Task {
            await liveScoreStreamer.disconnectAll()
        }
    }

    func scheduleLocalMatchReminders(enabled: Bool) async {
        guard enabled else {
            notificationMessage = nil
            return
        }

        do {
            await notificationService.configureCategories()
            let granted = try await notificationService.requestAuthorization()
            guard granted else {
                notificationMessage = String(localized: "notification.permissionDenied")
                return
            }

            for match in upcomingMatches {
                try await notificationService.scheduleMatchReminder(match: match)
            }

            notificationMessage = String(
                format: String(localized: "notification.remindersScheduled"),
                ArabicNumberFormatter.localized(upcomingMatches.count)
            )
        } catch {
            notificationMessage = error.localizedDescription
        }
    }

    func applyLiveUpdate(_ event: LiveScoreEvent) {
        if let teamID = event.teamID, let score = event.score {
            updateScore(matchID: event.matchID, teamID: teamID, score: score, in: &liveMatches)
        }
        updateLiveState(from: event, in: &liveMatches)
    }

    private func updateScore(matchID: String, teamID: String, score: Int, in matches: inout [Match]) {
        guard let index = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[index].scores[teamID] = score
    }

    private func updateLiveState(from event: LiveScoreEvent, in matches: inout [Match]) {
        guard let index = matches.firstIndex(where: { $0.id == event.matchID }) else { return }
        let current = matches[index].liveState
        matches[index].liveState = MatchLiveState(
            mapNumber: event.mapNumber ?? current?.mapNumber ?? 1,
            roundNumber: event.roundNumber ?? current?.roundNumber,
            clock: event.clock ?? current?.clock,
            phase: event.phase ?? event.rawType ?? current?.phase ?? "Live"
        )
    }
}
