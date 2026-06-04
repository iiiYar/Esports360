import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - State
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

    // MARK: - Published
    @Published private(set) var state: State = .idle
    @Published private(set) var liveConnectionState: LiveConnectionState = .disabled
    @Published private(set) var liveMatches:      [Match] = []
    @Published private(set) var upcomingMatches:  [Match] = []
    @Published private(set) var completedMatches: [Match] = []
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var refreshErrorMessage: String?
    @Published private(set) var notificationMessage: String?
    @Published private(set) var newsTickerItems: [String] = [
        "ticker.ewc", "ticker.saudiTeams", "ticker.fantasy"
    ]

    // Personalised computed outputs (published so View is pure)
    @Published private(set) var liveMatchesPrioritized: [Match] = []
    @Published private(set) var myAlertsGroupedSections: [GroupedMatchSection] = []

    // MARK: - Grouped section model
    struct GroupedMatchSection: Identifiable {
        let id = UUID()
        let dateHeader: String
        let subtitle: String
        let matches: [Match]
    }

    // MARK: - Dependencies
    private var repository: MatchRepository
    private let liveScoreStreamer: LiveScoreStreaming
    private let notificationService: NotificationService
    private var liveTasks: [Task<Void, Never>] = []
    private var loadGeneration = 0
    private var pollingTask: Task<Void, Never>?

    // MARK: - Init
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
        pollingTask?.cancel()
    }

    // MARK: - Repository
    func updateRepository(baseURL: String?) {
        repository = RepositoryFactory.makeMatchRepository(baseURL: baseURL)
    }

    #if DEBUG
    func replaceRepositoryForTesting(_ repository: MatchRepository) {
        self.repository = repository
    }
    #endif

    // MARK: - Load
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
        rebuildPersonalized()
    }

    // MARK: - Personalisation
    func rebuildPersonalized() {
        let favoriteGames = Set(UserDefaults.standard.stringArray(forKey: "user.favoriteGames") ?? [])
        let followedTeams = Set(UserDefaults.standard.stringArray(forKey: "user.followedTeams") ?? [])

        liveMatchesPrioritized = liveMatches.sorted { m1, m2 in
            let p1 = priority(m1, games: favoriteGames, teams: followedTeams)
            let p2 = priority(m2, games: favoriteGames, teams: followedTeams)
            return p1 != p2 ? p1 > p2 : (m1.beginAt ?? .distantFuture) < (m2.beginAt ?? .distantFuture)
        }

        let allMatches = liveMatches + upcomingMatches + completedMatches
        let myAlerts = allMatches.filter { match in
            favoriteGames.contains(match.game.rawValue)
            || match.teams.contains { followedTeams.contains($0.name) }
        }
        myAlertsGroupedSections = buildGroupedSections(from: myAlerts)
    }

    private func priority(_ match: Match, games: Set<String>, teams: Set<String>) -> Int {
        (games.contains(match.game.rawValue) ? 2 : 0)
        + (match.teams.contains { teams.contains($0.name) } ? 3 : 0)
    }

    private func buildGroupedSections(from matches: [Match]) -> [GroupedMatchSection] {
        let calendar = Calendar.current
        let grouped  = Dictionary(grouping: matches) { match -> Date in
            calendar.startOfDay(for: match.beginAt ?? Date())
        }
        return grouped.keys.sorted().map { date in
            let sectionMatches = (grouped[date] ?? [])
                .sorted { ($0.beginAt ?? .distantFuture) < ($1.beginAt ?? .distantFuture) }
            return GroupedMatchSection(
                dateHeader: dateHeaderString(for: date, calendar: calendar),
                subtitle: matchCountSubtitle(sectionMatches.count),
                matches: sectionMatches
            )
        }
    }

    private func dateHeaderString(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date)     { return String(localized: "home.today",     defaultValue: "— اليوم —") }
        if calendar.isDateInTomorrow(date)  { return String(localized: "home.tomorrow",  defaultValue: "— غداً —") }
        if calendar.isDateInYesterday(date) { return String(localized: "home.yesterday", defaultValue: "— أمس —") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "EEEE، d MMMM"
        return "— \(formatter.string(from: date)) —"
    }

    private func matchCountSubtitle(_ count: Int) -> String {
        switch count {
        case 1:  return String(localized: "home.oneMatch",  defaultValue: "مباراة واحدة")
        case 2:  return String(localized: "home.twoMatches", defaultValue: "مباراتان")
        default: return String(
                    format: String(localized: "home.nMatches", defaultValue: "%@ مباريات"),
                    ArabicNumberFormatter.localized(count)
                )
        }
    }

    // MARK: - Polling (replaces View-level Timer)
    func startPolling(interval: TimeInterval = 10) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                guard let self, self.state != .loading else { continue }
                await self.load(forceRefresh: true)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Live Updates
    func startLiveUpdates() {
        stopLiveUpdates()
        guard !liveMatches.isEmpty else {
            liveConnectionState = .disabled
            return
        }
        liveConnectionState = .unavailable
    }

    func stopLiveUpdates() {
        liveTasks.forEach { $0.cancel() }
        liveTasks.removeAll()
        Task { await liveScoreStreamer.disconnectAll() }
    }

    // MARK: - Notifications
    func scheduleLocalMatchReminders(enabled: Bool) async {
        guard enabled else { notificationMessage = nil; return }
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

    // MARK: - Live Score Events
    func applyLiveUpdate(_ event: LiveScoreEvent) {
        if let teamID = event.teamID, let score = event.score {
            updateScore(matchID: event.matchID, teamID: teamID, score: score, in: &liveMatches)
        }
        updateLiveState(from: event, in: &liveMatches)
        rebuildPersonalized()
    }

    private func updateScore(matchID: String, teamID: String, score: Int, in matches: inout [Match]) {
        guard let i = matches.firstIndex(where: { $0.id == matchID }) else { return }
        matches[i].scores[teamID] = score
    }

    private func updateLiveState(from event: LiveScoreEvent, in matches: inout [Match]) {
        guard let i = matches.firstIndex(where: { $0.id == event.matchID }) else { return }
        let current = matches[i].liveState
        matches[i].liveState = MatchLiveState(
            mapNumber:   event.mapNumber   ?? current?.mapNumber ?? 1,
            roundNumber: event.roundNumber ?? current?.roundNumber,
            clock:       event.clock       ?? current?.clock,
            phase:       event.phase       ?? event.rawType ?? current?.phase ?? "Live"
        )
    }
}
