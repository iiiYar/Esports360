import Foundation

struct Esports360APIConfiguration: Equatable {
    var baseURL: URL

    static let production = Esports360APIConfiguration(
        baseURL: URL(string: E360Constants.defaultBackendBaseURL)!
    )

    /// Reads user-overridden URL from Settings (dev mode) or returns production default.
    static func fromUserSettings() -> Esports360APIConfiguration {
        let stored = UserDefaults.standard
            .string(forKey: AppStorageKeys.backendBaseURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = stored, !raw.isEmpty, let url = URL(string: raw) else {
            return .production
        }
        return Esports360APIConfiguration(baseURL: url)
    }
}
