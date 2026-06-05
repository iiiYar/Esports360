import Foundation

actor Esports360APIClient {
    private let configuration: Esports360APIConfiguration
    private let httpClient: HTTPClient

    init(
        configuration: Esports360APIConfiguration = .fromUserSettings(),
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient    = httpClient
    }

    // MARK: - Matches
    func todaysMatches(limit: Int = 80, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] {
        try await list(path: "v1/matches/today", limit: limit, forceRefresh: forceRefresh)
    }

    func liveMatches(limit: Int = 50, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] {
        try await list(path: "v1/matches/live", limit: limit, forceRefresh: forceRefresh)
    }

    func upcomingMatches(limit: Int = 20, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] {
        try await list(path: "v1/matches/upcoming", limit: limit, forceRefresh: forceRefresh)
    }

    func recentMatches(limit: Int = 10, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] {
        try await list(path: "v1/matches/recent", limit: limit, forceRefresh: forceRefresh)
    }

    func match(id: String, forceRefresh: Bool = false) async throws -> BackendMatchDTO {
        let response: BackendItemResponse<BackendMatchDTO> = try await get(
            path: "v1/matches/\(id)",
            forceRefresh: forceRefresh
        )
        return response.data
    }

    // MARK: - Games
    func games(limit: Int = 50) async throws -> [BackendGameDTO] {
        try await list(path: "v1/games", limit: limit)
    }

    // MARK: - Teams
    func featuredTeams(limit: Int = 20, forceRefresh: Bool = false) async throws -> [BackendTeamDTO] {
        try await list(path: "v1/teams/featured", limit: limit, forceRefresh: forceRefresh)
    }

    func teams(limit: Int = 50, offset: Int = 0, forceRefresh: Bool = false) async throws -> BackendListResponse<BackendTeamDTO> {
        var queryItems = [
            URLQueryItem(name: "limit",  value: String(min(max(limit, 1), 1000))),
            URLQueryItem(name: "offset", value: String(max(offset, 0)))
        ]
        if forceRefresh {
            queryItems.append(URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))))
        }
        return try await get(path: "v1/teams", queryItems: queryItems, forceRefresh: forceRefresh)
    }

    func team(id: String) async throws -> BackendTeamDTO {
        let response: BackendItemResponse<BackendTeamDTO> = try await get(path: "v1/teams/\(id)")
        return response.data
    }

    // MARK: - Tournaments
    func tournaments(limit: Int = 80, forceRefresh: Bool = false) async throws -> [BackendTournamentDTO] {
        try await list(path: "v1/tournaments", limit: limit, forceRefresh: forceRefresh)
    }

    func tournament(id: String, forceRefresh: Bool = false) async throws -> BackendTournamentDTO {
        let response: BackendItemResponse<BackendTournamentDTO> = try await get(
            path: "v1/tournaments/\(id)",
            forceRefresh: forceRefresh
        )
        return response.data
    }

    func tournamentMatches(id: String, limit: Int = 40, forceRefresh: Bool = false) async throws -> [BackendTournamentMatchDTO] {
        try await list(path: "v1/tournaments/\(id)/matches", limit: limit, forceRefresh: forceRefresh)
    }

    func tournamentTeams(id: String, limit: Int = 40, forceRefresh: Bool = false) async throws -> [BackendTournamentTeamDTO] {
        try await list(path: "v1/tournaments/\(id)/teams", limit: limit, forceRefresh: forceRefresh)
    }

    // MARK: - Discover
    func discoverTrending() async throws -> DiscoverTrendingDTO {
        try await get(path: "v1/discover/trending")
    }

    func discoverSearch(query: String) async throws -> DiscoverSearchDTO {
        let response: BackendItemResponse<DiscoverSearchDTO> = try await get(
            path: "v1/discover/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return response.data
    }

    func gameHub(code: String) async throws -> GameHubDTO {
        let response: BackendItemResponse<GameHubDTO> = try await get(path: "v1/games/\(code)/hub")
        return response.data
    }

    // MARK: - Media URL resolver
    nonisolated func resolveMediaURL(_ rawValue: String?) -> URL? {
        BackendURLResolver.resolveBackendURL(rawValue, baseURL: configuration.baseURL)
    }

    // MARK: - Private helpers

    private func list<T: Decodable>(path: String, limit: Int, forceRefresh: Bool = false) async throws -> [T] {
        var queryItems = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 100)))]
        if forceRefresh {
            queryItems.append(URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))))
        }
        let response: BackendListResponse<T> = try await get(path: path, queryItems: queryItems, forceRefresh: forceRefresh)
        return response.data
    }

    private func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        forceRefresh: Bool = false
    ) async throws -> T {
        guard var components = URLComponents(
            url: configuration.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)

        if forceRefresh {
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }

        // ── Auth ────────────────────────────────────────────────────────────
        if let token = KeychainManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await httpClient.send(request, decoder: .pandaScore)
    }
}
