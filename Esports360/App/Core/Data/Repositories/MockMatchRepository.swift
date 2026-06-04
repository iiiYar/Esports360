import Foundation

struct MockMatchRepository: MatchRepository {
    func todaysMatches(forceRefresh: Bool = false) async throws -> [Match] {
        MockEsportsData.todayMatches
    }

    func match(id: String, forceRefresh: Bool = false) async throws -> Match {
        guard let match = MockEsportsData.match(id: id) ?? MockEsportsData.todayMatches.first(where: { $0.id == id }) else {
            throw URLError(.badServerResponse)
        }
        return match
    }
}
