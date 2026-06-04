import XCTest
@testable import Esports360

@MainActor
final class HomeViewModelLiveUpdateTests: XCTestCase {
    func testLoadDoesNotShowMockMatchesWhenRepositoryFails() async throws {
        let viewModel = HomeViewModel(repository: FailingMatchRepository())

        await viewModel.load()

        XCTAssertEqual(viewModel.liveMatches.count, 0)
        XCTAssertEqual(viewModel.upcomingMatches.count, 0)
        XCTAssertEqual(viewModel.completedMatches.count, 0)
        XCTAssertNotNil(viewModel.refreshErrorMessage)
        guard case .failed = viewModel.state else {
            return XCTFail("Expected failed state when the server refresh fails.")
        }
    }

    func testFailedRefreshKeepsExistingRealMatches() async throws {
        let viewModel = HomeViewModel(repository: MockMatchRepository())

        await viewModel.load()
        XCTAssertEqual(viewModel.liveMatches.count, 1)

        viewModel.replaceRepositoryForTesting(FailingMatchRepository())
        await viewModel.load(forceRefresh: true)

        XCTAssertEqual(viewModel.liveMatches.count, 1)
        XCTAssertNotNil(viewModel.refreshErrorMessage)
        guard case .failed = viewModel.state else {
            return XCTFail("Expected failed state while preserving existing data.")
        }
    }

    func testApplyLiveUpdateChangesVisibleHomeFeedScoreAndState() async throws {
        let viewModel = HomeViewModel(repository: MockMatchRepository())
        await viewModel.load()

        let liveMatch = try XCTUnwrap(viewModel.liveMatches.first)
        let team = try XCTUnwrap(liveMatch.firstTeam)

        viewModel.applyLiveUpdate(
            LiveScoreEvent(
                matchID: liveMatch.id,
                teamID: team.id,
                score: 3,
                rawType: "score_change",
                mapNumber: 3,
                roundNumber: 19,
                clock: "0:31",
                phase: "Clutch"
            )
        )

        let updatedMatch = try XCTUnwrap(viewModel.liveMatches.first)
        XCTAssertEqual(updatedMatch.scores[team.id], 3)
        XCTAssertEqual(updatedMatch.liveState?.roundNumber, 19)
        XCTAssertEqual(updatedMatch.liveState?.clock, "0:31")
        XCTAssertEqual(updatedMatch.liveState?.phase, "Clutch")
    }
}

private struct FailingMatchRepository: MatchRepository {
    func todaysMatches(forceRefresh: Bool = false) async throws -> [Match] {
        throw URLError(.badServerResponse)
    }

    func match(id: String, forceRefresh: Bool = false) async throws -> Match {
        throw URLError(.badServerResponse)
    }
}
