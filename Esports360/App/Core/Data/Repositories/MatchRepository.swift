import Foundation

protocol MatchRepositoryProtocol {
    func liveMatches(limit: Int, forceRefresh: Bool) async throws -> [BackendMatchDTO]
    func upcomingMatches(limit: Int, forceRefresh: Bool) async throws -> [BackendMatchDTO]
    func recentMatches(limit: Int, forceRefresh: Bool) async throws -> [BackendMatchDTO]
}

extension MatchRepositoryProtocol {
    func liveMatches(limit: Int = 50, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] { [] }
    func upcomingMatches(limit: Int = 20, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] { [] }
    func recentMatches(limit: Int = 10, forceRefresh: Bool = false) async throws -> [BackendMatchDTO] { [] }
}

protocol MatchRepository: MatchRepositoryProtocol {
    func todaysMatches(forceRefresh: Bool) async throws -> [Match]
    func match(id: String, forceRefresh: Bool) async throws -> Match
}

enum RepositoryFactory {
    static func makeAPIClient() -> Esports360APIClient {
        let storedBaseURL = UserDefaults.standard.string(forKey: AppStorageKeys.backendBaseURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBaseURL = storedBaseURL?.isEmpty == false ? storedBaseURL! : E360Constants.defaultBackendBaseURL
        let baseURL = URL(string: rawBaseURL) ?? URL(string: E360Constants.defaultBackendBaseURL)!
        return Esports360APIClient(configuration: Esports360APIConfiguration(baseURL: baseURL))
    }

    static func makeMatchRepository() -> MatchRepository {
        makeMatchRepository(baseURL: UserDefaults.standard.string(forKey: AppStorageKeys.backendBaseURL))
    }

    static func makeMatchRepository(baseURL: String?) -> MatchRepository {
        let normalizedBaseURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBaseURL = normalizedBaseURL?.isEmpty == false ? normalizedBaseURL! : E360Constants.defaultBackendBaseURL
        let url = URL(string: rawBaseURL) ?? URL(string: E360Constants.defaultBackendBaseURL)!
        return BackendMatchRepository(
            apiClient: Esports360APIClient(configuration: Esports360APIConfiguration(baseURL: url))
        )
    }
}
