import Foundation

/// Prefetches all game & well-known team logos on app launch
/// so they're available offline instantly.
enum LogoPrefetcher {

    /// Call once at app start to warm the local logo disk cache.
    static func prefetchAll() {
        Task.detached(priority: .utility) {
            let cache = ImageDiskCache.shared

            // ── Game logos (from backend media endpoints) ──
            let gameURLs: [URL] = EsportsGame.allCases.compactMap { game in
                guard game != .unknown else { return nil }
                return game.logoURL
            }

            // ── Team logos (from mock / hardcoded data for known teams) ──
            let knownTeams = [
                MockEsportsData.teamFalcons,
                MockEsportsData.twistedMinds,
                MockEsportsData.nasr,
                MockEsportsData.g2,
                MockEsportsData.fnatic,
                MockEsportsData.liquid,
                MockEsportsData.vitality,
                MockEsportsData.loud
            ]
            let teamURLs: [URL] = knownTeams.compactMap(\.imageURL)

            // Merge and deduplicate
            let allURLs = Array(Set(gameURLs + teamURLs))

            await cache.prefetch(allURLs)
        }
    }
}
