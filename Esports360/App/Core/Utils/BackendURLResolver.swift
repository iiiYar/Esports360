import Foundation

enum BackendURLResolver {
    private static let defaultBaseURL = URL(string: E360Constants.defaultBackendBaseURL)

    static func resolveBackendURL(_ rawValue: String?, baseURL: URL? = nil) -> URL? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }

        if rawValue.hasPrefix("http://") || rawValue.hasPrefix("https://") {
            return URL(string: rawValue)
        }

        let resolvedBaseURL = baseURL ?? defaultBaseURL
        if rawValue.hasPrefix("/"), let resolvedBaseURL {
            var components = URLComponents(url: resolvedBaseURL, resolvingAgainstBaseURL: false)
            components?.path = rawValue
            components?.query = nil
            return components?.url
        }

        if let resolvedBaseURL {
            return URL(string: rawValue, relativeTo: resolvedBaseURL)?.absoluteURL
        }

        return URL(string: rawValue)
    }
}
