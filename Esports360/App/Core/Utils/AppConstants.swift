import Foundation
import SwiftUI

// MARK: - AppStorage Keys / مفاتيح التخزين المحلي
enum AppStorageKeys {
    static let languageCode          = "app.languageCode"
    static let calendarIdentifier    = "app.calendarIdentifier"
    static let backendBaseURL        = "api.backendBaseURL"
    static let pandaScoreToken       = "api.pandaScoreToken"
    static let matchRemindersEnabled = "notifications.matchRemindersEnabled"
}

// MARK: - App Language / لغة التطبيق
enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic  = "ar"
    case english = "en"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .arabic:  "language.arabic"
        case .english: "language.english"
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .arabic:  .rightToLeft
        case .english: .leftToRight
        }
    }
}

// MARK: - App Constants / ثوابت التطبيق
enum E360Constants {
    static let appName         = "Esports360"
    static let arabicBrandName = "إي سبورتس ٣٦٠"
    static let tagline         = "Your game. Your world."
    static let arabicTagline   = "عالمك التنافسي"

    // MARK: Backend Base URL
    // DEBUG  → local Docker on LAN (192.168.0.193:8010)
    // RELEASE → production domain (replace before App Store submission)
    static var defaultBackendBaseURL: String {
        #if DEBUG
        return "http://192.168.0.193:8010"
        #else
        return "https://api.esports360.app"   // ← replace with real production URL
        #endif
    }
}
