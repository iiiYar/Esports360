import Foundation

struct PandaScoreConfiguration: Equatable {
    enum TokenTransport: Equatable {
        case bearerHeader
        case queryParameter
    }

    var baseURL: URL
    var liveBaseURL: URL
    var accessToken: String?
    var tokenTransport: TokenTransport

    static let production = PandaScoreConfiguration(
        baseURL: URL(string: "https://api.pandascore.co")!,
        liveBaseURL: URL(string: "wss://live.pandascore.co")!,
        accessToken: nil,
        tokenTransport: .bearerHeader
    )
}
