import Foundation

struct PandaScoreMatchRepository: MatchRepository {
    private let apiClient: PandaScoreAPIClient

    init(apiClient: PandaScoreAPIClient) {
        self.apiClient = apiClient
    }

    func todaysMatches(forceRefresh: Bool = false) async throws -> [Match] {
        try await apiClient
            .todaysMatches()
            .map { $0.toDomain() }
    }

    func match(id: String, forceRefresh: Bool = false) async throws -> Match {
        guard let match = try await todaysMatches(forceRefresh: forceRefresh).first(where: { $0.id == id }) else {
            throw URLError(.badServerResponse)
        }
        return match
    }
}
