import Foundation

enum ImageCacheConfiguration {
    static func configureSharedCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "esports360-image-cache"
        )
    }
}
