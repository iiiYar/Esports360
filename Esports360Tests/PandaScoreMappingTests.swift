import XCTest
@testable import Esports360

final class PandaScoreMappingTests: XCTestCase {
    func testPandaScoreMatchDecodesAndMapsToDomainModel() throws {
        let payload = Data(
            """
            [
              {
                "id": 595466,
                "name": "Team Falcons vs Fnatic",
                "status": "running",
                "begin_at": "2026-05-23T16:00:00Z",
                "end_at": null,
                "number_of_games": 3,
                "videogame": { "id": 26, "name": "Valorant", "slug": "valorant" },
                "opponents": [
                  {
                    "type": "Team",
                    "opponent": {
                      "id": 1,
                      "name": "Team Falcons",
                      "acronym": "FLC",
                      "image_url": "https://cdn.pandascore.co/images/team/image/1/falcons.png",
                      "location": "SA"
                    }
                  },
                  {
                    "type": "Team",
                    "opponent": {
                      "id": 2,
                      "name": "Fnatic",
                      "acronym": "FNC",
                      "image_url": "https://cdn.pandascore.co/images/team/image/2/fnatic.png",
                      "location": "GB"
                    }
                  }
                ],
                "results": [
                  { "team_id": 1, "score": 2 },
                  { "team_id": 2, "score": 1 }
                ],
                "league": {
                  "id": 10,
                  "name": "Valorant Champions Tour",
                  "image_url": "https://cdn.pandascore.co/images/league/image/10/vct.png"
                },
                "serie": { "id": 11, "full_name": "Riyadh 2026" },
                "tournament": {
                  "id": 12,
                  "name": "Esports World Cup Riyadh",
                  "begin_at": "2026-05-22T00:00:00Z",
                  "end_at": "2026-05-30T00:00:00Z",
                  "image_url": "https://cdn.pandascore.co/images/tournament/image/12/ewc.png"
                },
                "streams_list": []
              }
            ]
            """.utf8
        )

        let dtos = try JSONDecoder.pandaScore.decode([PandaScoreMatchDTO].self, from: payload)
        let match = try XCTUnwrap(dtos.first?.toDomain())

        XCTAssertEqual(match.id, "595466")
        XCTAssertEqual(match.game, .valorant)
        XCTAssertEqual(match.status, .live)
        XCTAssertEqual(match.bestOf, 3)
        XCTAssertEqual(match.firstTeam?.name, "Team Falcons")
        XCTAssertEqual(match.firstTeam?.imageURL?.absoluteString, "https://cdn.pandascore.co/images/team/image/1/falcons.png")
        XCTAssertEqual(match.tournament?.imageURL?.absoluteString, "https://cdn.pandascore.co/images/tournament/image/12/ewc.png")
        XCTAssertEqual(match.scores["1"], 2)
        XCTAssertTrue(match.isFeaturedSaudiMatch)
    }
}
