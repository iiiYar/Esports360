import Foundation

struct Team: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let acronym: String?
    let imageURL: URL?
    let countryCode: String?

    var displayName: String {
        acronym?.isEmpty == false ? acronym ?? name : name
    }
}
