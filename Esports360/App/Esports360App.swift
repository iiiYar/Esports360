import SwiftData
import SwiftUI

@main
struct Esports360App: App {
    @AppStorage(AppStorageKeys.languageCode) private var languageCode = AppLanguage.arabic.rawValue

    init() {
        ImageCacheConfiguration.configureSharedCache()
        LogoPrefetcher.prefetchAll()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.locale, Locale(identifier: languageCode))
                .environment(\.layoutDirection, AppLanguage(rawValue: languageCode)?.layoutDirection ?? .rightToLeft)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: CachedMatchEntity.self)
    }
}
