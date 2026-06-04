import Foundation

// MARK: - Protocol
protocol LiveScoreStreaming {
    func stream(matchID: String, token: String) async throws -> AsyncThrowingStream<LiveScoreEvent, Error>
    func disconnect(matchID: String) async
    func disconnectAll() async
}

// MARK: - LiveScoreEvent
struct LiveScoreEvent: Decodable, Equatable {
    let matchID:     String
    let teamID:      String?
    let score:       Int?
    let rawType:     String?
    let mapNumber:   Int?
    let roundNumber: Int?
    let clock:       String?
    let phase:       String?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id", teamID = "team_id", score
        case rawType = "type", mapNumber = "map_number"
        case roundNumber = "round_number", clock, phase
    }

    init(matchID: String, teamID: String?, score: Int?, rawType: String?,
         mapNumber: Int?, roundNumber: Int?, clock: String?, phase: String?) {
        self.matchID = matchID; self.teamID = teamID; self.score = score
        self.rawType = rawType; self.mapNumber = mapNumber
        self.roundNumber = roundNumber; self.clock = clock; self.phase = phase
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchID     = try c.decodeLossyString(forKey: .matchID)
        teamID      = try c.decodeLossyStringIfPresent(forKey: .teamID)
        score       = try c.decodeIfPresent(Int.self,    forKey: .score)
        rawType     = try c.decodeIfPresent(String.self, forKey: .rawType)
        mapNumber   = try c.decodeIfPresent(Int.self,    forKey: .mapNumber)
        roundNumber = try c.decodeIfPresent(Int.self,    forKey: .roundNumber)
        clock       = try c.decodeIfPresent(String.self, forKey: .clock)
        phase       = try c.decodeIfPresent(String.self, forKey: .phase)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String {
        if let v = try? decode(String.self, forKey: key) { return v }
        if let v = try? decode(Int.self,    forKey: key) { return String(v) }
        throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath + [key], debugDescription: "Expected String or Int"))
    }
    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
        try decodeNil(forKey: key) ? nil : try decodeLossyString(forKey: key)
    }
}

// MARK: - LiveScoreWebSocketManager
/// Routes through the Esports360 backend WebSocket proxy: /v1/ws/matches/{id}
/// The backend authenticates the JWT then forwards the upstream PandaScore WSS stream.
actor LiveScoreWebSocketManager: LiveScoreStreaming {
    private let session: URLSession
    private var tasks: [String: URLSessionWebSocketTask] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(matchID: String, token: String) async throws -> AsyncThrowingStream<LiveScoreEvent, Error> {
        let config = Esports360APIConfiguration.fromUserSettings()
        guard var components = URLComponents(
            url: config.baseURL.appending(path: "v1/ws/matches/\(matchID)"),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.invalidURL }

        // http → ws  |  https → wss
        components.scheme     = config.baseURL.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw APIError.invalidURL }

        tasks[matchID]?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: url)
        tasks[matchID] = task
        task.resume()

        return AsyncThrowingStream { continuation in
            let decoder = JSONDecoder.pandaScore

            func receiveNext() {
                task.receive { result in
                    switch result {
                    case .success(let message):
                        let data: Data
                        switch message {
                        case .data(let d):   data = d
                        case .string(let s): data = Data(s.utf8)
                        @unknown default:    receiveNext(); return
                        }
                        // Skip keepalive ping frames injected by the proxy
                        if let event = try? decoder.decode(LiveScoreEvent.self, from: data) {
                            continuation.yield(event)
                        }
                        receiveNext()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            }

            receiveNext()
            continuation.onTermination = { _ in task.cancel(with: .goingAway, reason: nil) }
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
