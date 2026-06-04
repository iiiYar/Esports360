import Foundation

actor PandaScoreAPIClient {
    private let configuration: PandaScoreConfiguration
    private let httpClient: HTTPClient

    init(
        configuration: PandaScoreConfiguration = .production,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    func todaysMatches(
        date: Date = .now,
        calendar: Calendar = .current,
        perPage: Int = 50
    ) async throws -> [PandaScoreMatchDTO] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw APIError.invalidURL
        }

        return try await matches(
            startDate: dayStart,
            endDate: dayEnd,
            perPage: perPage
        )
    }

    func matches(
        startDate: Date,
        endDate: Date,
        perPage: Int = 50
    ) async throws -> [PandaScoreMatchDTO] {
        var components = URLComponents(
            url: configuration.baseURL.appending(path: "matches"),
            resolvingAgainstBaseURL: false
        )

        let formatter = ISO8601DateFormatter.pandaScore
        components?.queryItems = [
            URLQueryItem(name: "range[begin_at]", value: "\(formatter.string(from: startDate)),\(formatter.string(from: endDate))"),
            URLQueryItem(name: "sort", value: "begin_at"),
            URLQueryItem(name: "per_page", value: String(min(max(perPage, 1), 100)))
        ]

        var request = try authenticatedRequest(from: components)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await httpClient.send(request, decoder: .pandaScore)
    }

    private func authenticatedRequest(from components: URLComponents?) throws -> URLRequest {
        guard var components else { throw APIError.invalidURL }
        guard let token = configuration.accessToken, token.isEmpty == false else {
            throw APIError.missingToken
        }

        switch configuration.tokenTransport {
        case .bearerHeader:
            guard let url = components.url else { throw APIError.invalidURL }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        case .queryParameter:
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "token", value: token))
            components.queryItems = queryItems
            guard let url = components.url else { throw APIError.invalidURL }
            return URLRequest(url: url)
        }
    }
}
