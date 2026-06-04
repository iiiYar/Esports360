import Foundation

struct Esports360APIConfiguration: Equatable {
    var baseURL: URL

    static let production = Esports360APIConfiguration(
        baseURL: URL(string: E360Constants.defaultBackendBaseURL)!
    )
}
