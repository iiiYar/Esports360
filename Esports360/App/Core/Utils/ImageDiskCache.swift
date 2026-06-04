import Foundation
import UIKit

/// A dedicated disk cache for game & team logos.
/// Downloads images from the backend and stores them locally so
/// they load instantly offline and don't hit the network repeatedly.
actor ImageDiskCache {

    static let shared = ImageDiskCache()

    private let cacheDirectory: URL
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("esports360-logos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.urlCache = URLCache.shared
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Returns a local file URL for the given remote image, downloading it first if not cached.
    func localURL(for remoteURL: URL) async -> URL? {
        let key = cacheKey(for: remoteURL)
        let localFile = cacheDirectory.appendingPathComponent(key)

        // Already cached on disk
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }

        // Download and persist
        do {
            let (data, response) = try await session.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.isEmpty == false else {
                return nil
            }
            try data.write(to: localFile, options: .atomic)
            return localFile
        } catch {
            return nil
        }
    }

    /// Returns cached data synchronously if available, nil otherwise.
    func cachedData(for remoteURL: URL) -> Data? {
        let key = cacheKey(for: remoteURL)
        let localFile = cacheDirectory.appendingPathComponent(key)
        return FileManager.default.contents(atPath: localFile.path)
    }

    /// Returns true if a cached version already exists locally.
    func isCached(_ remoteURL: URL) -> Bool {
        let key = cacheKey(for: remoteURL)
        let localFile = cacheDirectory.appendingPathComponent(key)
        return FileManager.default.fileExists(atPath: localFile.path)
    }

    /// Prefetches a batch of URLs concurrently (fire-and-forget).
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    _ = await self?.localURL(for: url)
                }
            }
        }
    }

    /// Clears the entire disk cache.
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Total bytes used by cached logos.
    var diskUsage: Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - Private

    /// Generates a safe filename from a URL by hashing its absolute string.
    private func cacheKey(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let hash = url.absoluteString.utf8.reduce(into: UInt64(5381)) { result, byte in
            result = ((result << 5) &+ result) &+ UInt64(byte) // djb2 hash
        }
        return ext.isEmpty ? "\(hash)" : "\(hash).\(ext)"
    }
}
