import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case missingToken
    case invalidResponse
    case statusCode(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL."
        case .missingToken:
            "Missing API token."
        case .invalidResponse:
            "Invalid server response."
        case .statusCode(let code):
            "Request failed with status code \(code)."
        case .decoding(let message):
            "Failed to decode response: \(message)"
        }
    }
}
