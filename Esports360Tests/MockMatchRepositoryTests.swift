import XCTest
@testable import Esports360

final class MockMatchRepositoryTests: XCTestCase {
    func testTodaysMatchesAreGroupedByStatusReadyForHomeFeed() async throws {
        let repository = MockMatchRepository()

        let matches = try await repository.todaysMatches(forceRefresh: true)

        XCTAssertEqual(matches.filter { $0.status == .live }.count, 1)
        XCTAssertEqual(matches.filter { $0.status == .upcoming }.count, 1)
        XCTAssertEqual(matches.filter { $0.status == .finished }.count, 1)
        XCTAssertTrue(matches.contains(where: \.isFeaturedSaudiMatch))
    }
}
