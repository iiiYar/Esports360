import Foundation

struct Tournament: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let leagueName: String?
    let serieName: String?
    let beginAt: Date?
    let endAt: Date?
    let imageURL: URL?
}
