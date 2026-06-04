import XCTest
@testable import Esports360

@MainActor
final class DeepLinkRouterTests: XCTestCase {
    func testParsesUniversalLinksForCoreEntities() {
        XCTAssertEqual(
            DeepLinkRouter.destination(for: URL(string: "https://esports360.app/match/1001")!),
            .match("1001")
        )
        XCTAssertEqual(
            DeepLinkRouter.destination(for: URL(string: "https://esports360.app/team/1")!),
            .team("1")
        )
        XCTAssertEqual(
            DeepLinkRouter.destination(for: URL(string: "https://esports360.app/tournament/701")!),
            .tournament("701")
        )
    }

    func testParsesCustomSchemeAsSimulatorFallback() {
        XCTAssertEqual(
            DeepLinkRouter.destination(for: URL(string: "esports360://player/9001")!),
            .player("9001")
        )
    }
}
