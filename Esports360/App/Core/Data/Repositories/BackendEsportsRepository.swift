import Foundation

struct BackendMatchRepository: MatchRepository {
    private let apiClient: Esports360APIClient

    init(apiClient: Esports360APIClient) {
        self.apiClient = apiClient
    }

    func todaysMatches(forceRefresh: Bool = false) async throws -> [Match] {
        let dtos = try await apiClient.todaysMatches(forceRefresh: forceRefresh)
        var matches: [Match] = []
        for dto in dtos {
            matches.append(await dto.toDomain(apiClient: apiClient))
        }
        return matches
    }

    func match(id: String, forceRefresh: Bool = false) async throws -> Match {
        let dto = try await apiClient.match(id: id, forceRefresh: forceRefresh)
        return await dto.toDomain(apiClient: apiClient)
    }
}

struct BackendCatalogRepository {
    private let apiClient: Esports360APIClient

    init(apiClient: Esports360APIClient = RepositoryFactory.makeAPIClient()) {
        self.apiClient = apiClient
    }

    func games() async throws -> [GameCatalogItem] {
        try await apiClient.games().map { $0.toCatalogItem(apiClient: apiClient) }
    }
}

struct BackendTeamRepository {
    private let apiClient: Esports360APIClient

    init(apiClient: Esports360APIClient = RepositoryFactory.makeAPIClient()) {
        self.apiClient = apiClient
    }

    func featuredTeams() async throws -> [TeamProfile] {
        let teams = try await apiClient.featuredTeams()
        var profiles: [TeamProfile] = []
        for team in teams {
            profiles.append(try await teamProfile(id: team.id))
        }
        return profiles
    }

    func teamProfile(id: String) async throws -> TeamProfile {
        try await apiClient.team(id: id).toProfile(apiClient: apiClient)
    }
}

struct BackendTournamentRepository {
    private let apiClient: Esports360APIClient

    init(apiClient: Esports360APIClient = RepositoryFactory.makeAPIClient()) {
        self.apiClient = apiClient
    }

    func tournaments(forceRefresh: Bool = false) async throws -> [BackendTournamentDTO] {
        try await apiClient.tournaments(forceRefresh: forceRefresh)
    }

    func tournament(id: String, forceRefresh: Bool = false) async throws -> BackendTournamentDTO {
        try await apiClient.tournament(id: id, forceRefresh: forceRefresh)
    }

    func resolveURL(_ rawValue: String?) -> URL? {
        apiClient.resolveMediaURL(rawValue)
    }
}
