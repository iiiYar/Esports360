import Foundation

protocol LiveScoreStreaming {
    func stream(matchID: String, token: String) async throws -> AsyncThrowingStream<LiveScoreEvent, Error>
    func disconnect(matchID: String) async
    func disconnectAll() async
}

struct LiveScoreEvent: Decodable, Equatable {
    let matchID: String
    let teamID: String?
    let score: Int?
    let rawType: String?
    let mapNumber: Int?
    let roundNumber: Int?
    let clock: String?
    let phase: String?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case teamID = "team_id"
        case score
        case rawType = "type"
        case mapNumber = "map_number"
        case roundNumber = "round_number"
        case clock
        case phase
    }

    init(
        matchID: String,
        teamID: String?,
        score: Int?,
        rawType: String?,
        mapNumber: Int?,
        roundNumber: Int?,
        clock: String?,
        phase: String?
    ) {
        self.matchID = matchID
        self.teamID = teamID
        self.score = score
        self.rawType = rawType
        self.mapNumber = mapNumber
        self.roundNumber = roundNumber
        self.clock = clock
        self.phase = phase
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matchID = try container.decodeLossyString(forKey: .matchID)
        teamID = try container.decodeLossyStringIfPresent(forKey: .teamID)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        rawType = try container.decodeIfPresent(String.self, forKey: .rawType)
        mapNumber = try container.decodeIfPresent(Int.self, forKey: .mapNumber)
        roundNumber = try container.decodeIfPresent(Int.self, forKey: .roundNumber)
        clock = try container.decodeIfPresent(String.self, forKey: .clock)
        phase = try container.decodeIfPresent(String.self, forKey: .phase)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Expected string or integer.")
        )
    }

    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
        if try decodeNil(forKey: key) {
            return nil
        }
        return try decodeLossyString(forKey: key)
    }
}

actor LiveScoreWebSocketManager: LiveScoreStreaming {
    private let configuration: PandaScoreConfiguration
    private let session: URLSession
    private var tasks: [String: URLSessionWebSocketTask] = [:]

    init(
        configuration: PandaScoreConfiguration = .production,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func stream(matchID: String, token: String) async throws -> AsyncThrowingStream<LiveScoreEvent, Error> {
        var components = URLComponents(
            url: configuration.liveBaseURL.appending(path: "matches/\(matchID)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let task = session.webSocketTask(with: url)
        tasks[matchID]?.cancel(with: .goingAway, reason: nil)
        tasks[matchID] = task
        task.resume()

        return AsyncThrowingStream { continuation in
            let decoder = JSONDecoder.pandaScore

            func receiveNext() {
                task.receive { result in
                    switch result {
                    case .success(let message):
                        do {
                            let data: Data
                            switch message {
                            case .data(let payload):
                                data = payload
                            case .string(let text):
                                data = Data(text.utf8)
                            @unknown default:
                                throw APIError.invalidResponse
                            }

                            if let event = try? decoder.decode(LiveScoreEvent.self, from: data) {
                                continuation.yield(event)
                            }
                            receiveNext()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            }

            receiveNext()
            continuation.onTermination = { _ in
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func disconnect(matchID: String) async {
        tasks[matchID]?.cancel(with: .goingAway, reason: nil)
        tasks[matchID] = nil
    }

    func disconnectAll() async {
        tasks.values.forEach { $0.cancel(with: .goingAway, reason: nil) }
        tasks.removeAll()
    }
}
