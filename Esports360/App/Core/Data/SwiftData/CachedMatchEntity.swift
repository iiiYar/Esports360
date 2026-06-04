import Foundation
import SwiftData

@Model
final class CachedMatchEntity {
    @Attribute(.unique) var id: String
    var payload: Data
    var cachedAt: Date
    var ttlSeconds: TimeInterval

    init(id: String, payload: Data, cachedAt: Date = .now, ttlSeconds: TimeInterval = 86_400) {
        self.id = id
        self.payload = payload
        self.cachedAt = cachedAt
        self.ttlSeconds = ttlSeconds
    }

    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > ttlSeconds
    }
}
