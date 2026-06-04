import Foundation

// MARK: - Esports360 API Configuration / إعداد الـ API

struct Esports360APIConfiguration: Equatable {
    var baseURL: URL

    // MARK: Built from E360Constants — switches automatically DEBUG ↔ RELEASE
    static let production = Esports360APIConfiguration(
        baseURL: URL(string: E360Constants.defaultBackendBaseURL)!
    )

    // MARK: Reads user-overridden URL from Settings screen (dev convenience)
    static func fromUserSettings() -> Esports360APIConfiguration {
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.backendBaseURL)
        let raw    = (stored?.isEmpty == false) ? stored! : E360Constants.defaultBackendBaseURL
        let url    = URL(string: raw) ?? URL(string: E360Constants.defaultBackendBaseURL)!
        return Esports360APIConfiguration(baseURL: url)
    }
}
