import Foundation

enum MockEsportsData {
    private static let logoBaseURL = "https://raw.githubusercontent.com/lootmarket/esport-team-logos/master"

    static let teamFalcons = Team(id: "1", name: "Team Falcons", acronym: "FLC", imageURL: teamLogo("valorant/falcons/falcons-logo.png"), countryCode: "SA")
    static let fnatic = Team(id: "2", name: "Fnatic", acronym: "FNC", imageURL: teamLogo("valorant/fnatic/fnatic-logo.png"), countryCode: "GB")
    static let twistedMinds = Team(id: "3", name: "Twisted Minds", acronym: "TM", imageURL: teamLogo("rocket-league/twisted-minds/twisted-minds-logo.png"), countryCode: "SA")
    static let g2 = Team(id: "4", name: "G2 Esports", acronym: "G2", imageURL: teamLogo("rocket-league/g2-esports/g2-esports-logo.png"), countryCode: "US")
    static let nasr = Team(id: "5", name: "Nasr Esports", acronym: "NASR", imageURL: teamLogo("cs/nasr-esports/nasr-esports-logo.png"), countryCode: "AE")
    static let liquid = Team(id: "6", name: "Team Liquid", acronym: "TL", imageURL: teamLogo("cs/team-liquid/team-liquid-logo.png"), countryCode: "NL")
    static let vitality = Team(id: "7", name: "Team Vitality", acronym: "VIT", imageURL: teamLogo("cs/team-vitality/team-vitality-logo.png"), countryCode: "FR")
    static let loud = Team(id: "8", name: "LOUD", acronym: "LOUD", imageURL: teamLogo("valorant/loud/loud-logo.png"), countryCode: "BR")

    static let falconsRoster: [PlayerProfile] = [
        PlayerProfile(
            id: "9001",
            handle: "trk511",
            realName: "Turki",
            role: "Duelist",
            countryCode: "SA",
            imageURL: nil,
            kdRatio: 1.24,
            winRate: 68,
            matchesPlayed: 54,
            kdTrend: kdTrend([1.08, 1.14, 1.20, 1.17, 1.24]),
            pool: ["Raze", "Jett", "Neon", "Phoenix"]
        ),
        PlayerProfile(
            id: "9002",
            handle: "M7sn",
            realName: "Mohammed",
            role: "Initiator",
            countryCode: "SA",
            imageURL: nil,
            kdRatio: 1.09,
            winRate: 64,
            matchesPlayed: 49,
            kdTrend: kdTrend([0.98, 1.02, 1.11, 1.06, 1.09]),
            pool: ["Sova", "Fade", "Breach", "KAY/O"]
        ),
        PlayerProfile(
            id: "9003",
            handle: "Kiileerrz",
            realName: nil,
            role: "Controller",
            countryCode: "SA",
            imageURL: nil,
            kdRatio: 1.16,
            winRate: 66,
            matchesPlayed: 51,
            kdTrend: kdTrend([1.04, 1.07, 1.12, 1.18, 1.16]),
            pool: ["Omen", "Viper", "Astra", "Brimstone"]
        ),
        PlayerProfile(
            id: "9004",
            handle: "Rw9",
            realName: nil,
            role: "Sentinel",
            countryCode: "SA",
            imageURL: nil,
            kdRatio: 1.31,
            winRate: 70,
            matchesPlayed: 58,
            kdTrend: kdTrend([1.18, 1.25, 1.22, 1.28, 1.31]),
            pool: ["Killjoy", "Cypher", "Sage", "Chamber"]
        ),
        PlayerProfile(
            id: "9005",
            handle: "Ahmad",
            realName: "Ahmad",
            role: "Flex",
            countryCode: "SA",
            imageURL: nil,
            kdRatio: 1.13,
            winRate: 62,
            matchesPlayed: 45,
            kdTrend: kdTrend([1.01, 1.05, 1.07, 1.10, 1.13]),
            pool: ["Skye", "Raze", "Gekko", "Omen"]
        )
    ]

    static let teamFalconsProfile = TeamProfile(
        id: teamFalcons.id,
        team: teamFalcons,
        game: .valorant,
        gameImageURL: nil,
        roster: falconsRoster,
        recentResults: [
            TeamMatchResult(id: "1", opponent: fnatic, outcome: .win, score: "2-1", tournamentName: "Esports World Cup Riyadh", playedAt: .now.addingTimeInterval(-3_600)),
            TeamMatchResult(id: "2", opponent: g2, outcome: .loss, score: "1-2", tournamentName: "Saudi eLeague", playedAt: .now.addingTimeInterval(-86_400)),
            TeamMatchResult(id: "3", opponent: nasr, outcome: .win, score: "2-0", tournamentName: "MENA Masters", playedAt: .now.addingTimeInterval(-172_800)),
            TeamMatchResult(id: "4", opponent: liquid, outcome: .win, score: "2-1", tournamentName: "MENA Masters", playedAt: .now.addingTimeInterval(-259_200)),
            TeamMatchResult(id: "5", opponent: vitality, outcome: .loss, score: "0-2", tournamentName: "Valorant Champions Tour", playedAt: .now.addingTimeInterval(-345_600))
        ],
        winRateHistory: [
            StatPoint(label: "W1", value: 58),
            StatPoint(label: "W2", value: 61),
            StatPoint(label: "W3", value: 65),
            StatPoint(label: "W4", value: 63),
            StatPoint(label: "W5", value: 68)
        ],
        form: [.win, .loss, .win, .win, .loss]
    )

    static let teamProfiles: [TeamProfile] = [
        teamFalconsProfile,
        TeamProfile(
            id: twistedMinds.id,
            team: twistedMinds,
            game: .rocketLeague,
            gameImageURL: nil,
            roster: falconsRoster.map { player in
                PlayerProfile(
                    id: "\(player.id)-rl",
                    handle: player.handle,
                    realName: player.realName,
                    role: player.role,
                    countryCode: player.countryCode,
                    imageURL: player.imageURL,
                    kdRatio: player.kdRatio - 0.04,
                    winRate: player.winRate - 3,
                    matchesPlayed: player.matchesPlayed - 6,
                    kdTrend: player.kdTrend,
                    pool: player.pool
                )
            },
            recentResults: teamFalconsProfile.recentResults,
            winRateHistory: [
                StatPoint(label: "W1", value: 54),
                StatPoint(label: "W2", value: 57),
                StatPoint(label: "W3", value: 60),
                StatPoint(label: "W4", value: 59),
                StatPoint(label: "W5", value: 64)
            ],
            form: [.win, .win, .draw, .loss, .win]
        ),
        TeamProfile(
            id: nasr.id,
            team: nasr,
            game: .counterStrike,
            gameImageURL: nil,
            roster: falconsRoster.map { player in
                PlayerProfile(
                    id: "\(player.id)-cs",
                    handle: player.handle,
                    realName: player.realName,
                    role: player.role,
                    countryCode: "AE",
                    imageURL: player.imageURL,
                    kdRatio: player.kdRatio - 0.08,
                    winRate: player.winRate - 7,
                    matchesPlayed: player.matchesPlayed - 9,
                    kdTrend: player.kdTrend,
                    pool: ["AWP", "Entry", "IGL", "Support"]
                )
            },
            recentResults: [
                TeamMatchResult(id: "11", opponent: liquid, outcome: .loss, score: "0-2", tournamentName: "MENA Masters", playedAt: .now.addingTimeInterval(-3_600)),
                TeamMatchResult(id: "12", opponent: twistedMinds, outcome: .win, score: "2-1", tournamentName: "Saudi eLeague", playedAt: .now.addingTimeInterval(-86_400)),
                TeamMatchResult(id: "13", opponent: fnatic, outcome: .loss, score: "1-2", tournamentName: "Valorant Champions Tour", playedAt: .now.addingTimeInterval(-172_800)),
                TeamMatchResult(id: "14", opponent: g2, outcome: .draw, score: "1-1", tournamentName: "MENA Masters", playedAt: .now.addingTimeInterval(-259_200)),
                TeamMatchResult(id: "15", opponent: vitality, outcome: .win, score: "2-0", tournamentName: "MENA Masters", playedAt: .now.addingTimeInterval(-345_600))
            ],
            winRateHistory: [
                StatPoint(label: "W1", value: 49),
                StatPoint(label: "W2", value: 52),
                StatPoint(label: "W3", value: 50),
                StatPoint(label: "W4", value: 55),
                StatPoint(label: "W5", value: 57)
            ],
            form: [.loss, .win, .loss, .draw, .win]
        )
    ]

    static let todayMatches: [Match] = [
        Match(
            id: "1001",
            name: "Team Falcons vs Fnatic",
            game: .valorant,
            gameImageURL: nil,
            status: .live,
            beginAt: .now.addingTimeInterval(-900),
            endAt: nil,
            tournament: Tournament(
                id: "401",
                name: "Esports World Cup Riyadh",
                leagueName: "Valorant Champions Tour",
                serieName: "Riyadh 2026",
                beginAt: .now.addingTimeInterval(-86_400),
                endAt: .now.addingTimeInterval(604_800),
                imageURL: nil
            ),
            teams: [teamFalcons, fnatic],
            scores: [teamFalcons.id: 2, fnatic.id: 1],
            bestOf: 3,
            streamURL: URL(string: "https://twitch.tv/esportsworldcup"),
            streams: [
                MatchStream(
                    id: "mock-ewc-twitch",
                    title: "Esports World Cup",
                    provider: "twitch",
                    language: "ar",
                    url: URL(string: "https://twitch.tv/esportsworldcup")!,
                    thumbnailURL: nil,
                    viewerCount: 12400,
                    isLive: true,
                    isOfficial: true
                )
            ],
            liveState: MatchLiveState(mapNumber: 3, roundNumber: 18, clock: "0:42", phase: "Attack side"),
            maps: [
                MatchMap(
                    id: "1001-map-1",
                    number: 1,
                    mapName: "Haven",
                    status: "completed",
                    startedAt: .now.addingTimeInterval(-6_300),
                    endedAt: .now.addingTimeInterval(-4_500),
                    durationSeconds: 1_800,
                    scores: [
                        MatchMapScore(teamID: teamFalcons.id, totalRounds: 13, firstHalfRounds: 7, secondHalfRounds: 6, overtimeRounds: nil, currentSide: nil),
                        MatchMapScore(teamID: fnatic.id, totalRounds: 8, firstHalfRounds: 5, secondHalfRounds: 3, overtimeRounds: nil, currentSide: nil)
                    ]
                ),
                MatchMap(
                    id: "1001-map-2",
                    number: 2,
                    mapName: "Bind",
                    status: "completed",
                    startedAt: .now.addingTimeInterval(-4_200),
                    endedAt: .now.addingTimeInterval(-2_100),
                    durationSeconds: 2_100,
                    scores: [
                        MatchMapScore(teamID: teamFalcons.id, totalRounds: 10, firstHalfRounds: 6, secondHalfRounds: 4, overtimeRounds: nil, currentSide: nil),
                        MatchMapScore(teamID: fnatic.id, totalRounds: 13, firstHalfRounds: 6, secondHalfRounds: 7, overtimeRounds: nil, currentSide: nil)
                    ]
                ),
                MatchMap(
                    id: "1001-map-3",
                    number: 3,
                    mapName: "Split",
                    status: "live",
                    startedAt: .now.addingTimeInterval(-900),
                    endedAt: nil,
                    durationSeconds: nil,
                    scores: [
                        MatchMapScore(teamID: teamFalcons.id, totalRounds: 12, firstHalfRounds: 7, secondHalfRounds: 5, overtimeRounds: nil, currentSide: "CT"),
                        MatchMapScore(teamID: fnatic.id, totalRounds: 5, firstHalfRounds: 5, secondHalfRounds: 0, overtimeRounds: nil, currentSide: "T")
                    ]
                )
            ],
            teamCompositions: [
                teamFalcons.id: ["Raze", "Omen", "Sova", "Killjoy", "Breach"],
                fnatic.id: ["Jett", "Viper", "Fade", "Cypher", "KAY/O"]
            ]
        ),
        Match(
            id: "1002",
            name: "Twisted Minds vs G2 Esports",
            game: .rocketLeague,
            gameImageURL: nil,
            status: .upcoming,
            beginAt: .now.addingTimeInterval(3_600),
            endAt: nil,
            tournament: Tournament(
                id: "402",
                name: "Saudi eLeague",
                leagueName: "Rocket League",
                serieName: "Spring Split",
                beginAt: .now,
                endAt: .now.addingTimeInterval(432_000),
                imageURL: nil
            ),
            teams: [twistedMinds, g2],
            scores: [twistedMinds.id: 0, g2.id: 0],
            bestOf: 5,
            streamURL: nil,
            streams: [],
            liveState: nil,
            maps: [],
            teamCompositions: [
                twistedMinds.id: ["Ahmad", "trk511", "M7sn", "Kiileerrz", "Rw9"],
                g2.id: ["Atomic", "Daniel", "BeastMode", "Coach", "Sub"]
            ]
        ),
        Match(
            id: "1003",
            name: "Nasr Esports vs Team Liquid",
            game: .counterStrike,
            gameImageURL: nil,
            status: .finished,
            beginAt: .now.addingTimeInterval(-7_200),
            endAt: .now.addingTimeInterval(-3_600),
            tournament: Tournament(
                id: "403",
                name: "MENA Masters",
                leagueName: "Counter-Strike 2",
                serieName: "Group Stage",
                beginAt: .now.addingTimeInterval(-172_800),
                endAt: .now.addingTimeInterval(172_800),
                imageURL: nil
            ),
            teams: [nasr, liquid],
            scores: [nasr.id: 0, liquid.id: 2],
            bestOf: 3,
            streamURL: nil,
            streams: [],
            liveState: MatchLiveState(mapNumber: 2, roundNumber: 24, clock: nil, phase: "Final"),
            maps: [
                MatchMap(id: "1003-map-1", number: 1, mapName: "Ancient", status: "completed", startedAt: .now.addingTimeInterval(-7_200), endedAt: .now.addingTimeInterval(-5_700), durationSeconds: 1_500, scores: []),
                MatchMap(id: "1003-map-2", number: 2, mapName: "Mirage", status: "completed", startedAt: .now.addingTimeInterval(-5_400), endedAt: .now.addingTimeInterval(-3_600), durationSeconds: 1_800, scores: [])
            ],
            teamCompositions: [
                nasr.id: ["AWP", "Entry", "IGL", "Support", "Lurk"],
                liquid.id: ["AWP", "Entry", "IGL", "Support", "Anchor"]
            ]
        )
    ]

    static let ewcTournament = TournamentBracket(
        id: "701",
        tournament: Tournament(
            id: "701",
            name: "Esports World Cup Riyadh",
            leagueName: "Valorant Champions Tour",
            serieName: "Riyadh 2026",
            beginAt: .now.addingTimeInterval(-86_400),
            endAt: .now.addingTimeInterval(604_800),
            imageURL: nil
        ),
        game: .valorant,
        rounds: [
            BracketRound(
                id: "1",
                title: "Quarterfinals",
                matches: [
                    BracketMatch(id: "7101", firstTeam: teamFalcons, secondTeam: fnatic, firstScore: 2, secondScore: 1, winnerTeamID: teamFalcons.id, status: .finished),
                    BracketMatch(id: "7102", firstTeam: twistedMinds, secondTeam: g2, firstScore: 1, secondScore: 2, winnerTeamID: g2.id, status: .finished),
                    BracketMatch(id: "7103", firstTeam: nasr, secondTeam: liquid, firstScore: 0, secondScore: 2, winnerTeamID: liquid.id, status: .finished),
                    BracketMatch(id: "7104", firstTeam: vitality, secondTeam: loud, firstScore: 2, secondScore: 0, winnerTeamID: vitality.id, status: .finished)
                ]
            ),
            BracketRound(
                id: "2",
                title: "Semifinals",
                matches: [
                    BracketMatch(id: "7201", firstTeam: teamFalcons, secondTeam: g2, firstScore: 0, secondScore: 0, winnerTeamID: nil, status: .upcoming),
                    BracketMatch(id: "7202", firstTeam: liquid, secondTeam: vitality, firstScore: 0, secondScore: 0, winnerTeamID: nil, status: .upcoming)
                ]
            ),
            BracketRound(
                id: "3",
                title: "Grand Final",
                matches: [
                    BracketMatch(id: "7301", firstTeam: teamFalcons, secondTeam: vitality, firstScore: 0, secondScore: 0, winnerTeamID: nil, status: .upcoming)
                ]
            )
        ],
        standings: [
            GroupStanding(id: "1", team: teamFalcons, points: 9, wins: 3, losses: 0, draws: 0, mapDifferential: 5),
            GroupStanding(id: "2", team: fnatic, points: 6, wins: 2, losses: 1, draws: 0, mapDifferential: 2),
            GroupStanding(id: "3", team: g2, points: 4, wins: 1, losses: 1, draws: 1, mapDifferential: 0),
            GroupStanding(id: "4", team: twistedMinds, points: 3, wins: 1, losses: 2, draws: 0, mapDifferential: -1),
            GroupStanding(id: "5", team: nasr, points: 1, wins: 0, losses: 2, draws: 1, mapDifferential: -4)
        ]
    )

    static func teamProfile(id: String) -> TeamProfile? {
        teamProfiles.first { $0.id == id } ?? (id == teamFalcons.id ? teamFalconsProfile : nil)
    }

    static func playerProfile(id: String) -> PlayerProfile? {
        teamProfiles.flatMap(\.roster).first { $0.id == id }
    }

    static func tournamentBracket(id: String) -> TournamentBracket? {
        id == ewcTournament.id || id == ewcTournament.tournament.id ? ewcTournament : nil
    }

    static func match(id: String) -> Match? {
        todayMatches.first { $0.id == id }
    }

    private static func kdTrend(_ values: [Double]) -> [StatPoint] {
        values.enumerated().map { index, value in
            StatPoint(label: "M\(index + 1)", value: value)
        }
    }

    private static func teamLogo(_ path: String) -> URL? {
        URL(string: "\(logoBaseURL)/\(path)")
    }
}
