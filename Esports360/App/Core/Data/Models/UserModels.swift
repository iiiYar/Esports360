import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
    let locale: String
    let timezone: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case locale
        case timezone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserPreferences: Codable, Hashable {
    var language: String
    var calendarPreference: String
    var saudiFanMode: Bool
    var notificationsEnabled: Bool
    var notifMatchStart: Bool
    var notifScoreChange: Bool
    var notifMatchEnd: Bool
    var notifRosterChange: Bool
    var notifStreamLive: Bool
    var notifFantasyRemind: Bool
    
    static let `default` = UserPreferences(
        language: "ar",
        calendarPreference: "gregorian",
        saudiFanMode: false,
        notificationsEnabled: true,
        notifMatchStart: true,
        notifScoreChange: true,
        notifMatchEnd: true,
        notifRosterChange: true,
        notifStreamLive: true,
        notifFantasyRemind: true
    )
}

struct UserFollow: Codable, Hashable {
    let entityType: String
    let entityId: String
    let notificationLevel: String
    let entityName: String?
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
