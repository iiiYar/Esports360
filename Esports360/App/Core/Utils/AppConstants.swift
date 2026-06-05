import Foundation
import SwiftUI

enum AppStorageKeys {
    // App
    static let languageCode             = "app.languageCode"
    static let calendarIdentifier       = "app.calendarIdentifier"
    static let hasCompletedOnboarding   = "app.hasCompletedOnboarding"
    static let bigGameDismissed         = "home.bigGameDismissed"
    // User prefs
    static let favoriteGames            = "user.favoriteGames"
    static let followedTeams            = "user.followedTeams"
    // API
    static let backendBaseURL           = "api.backendBaseURL"
    static let pandaScoreToken          = "api.pandaScoreToken"
    // Notifications
    static let matchRemindersEnabled    = "notifications.matchRemindersEnabled"
}

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

enum E360Constants {
    static let appName             = "Esports360"
    static let arabicBrandName     = "\u0625\u064a \u0633\u0628\u0648\u0631\u062a\u0633 \u0663\u0666\u0660"
    static let tagline             = "Your game. Your world."
    static let arabicTagline       = "\u0639\u0627\u0644\u0645\u0643 \u0627\u0644\u062a\u0646\u0627\u0641\u0633\u064a"
    static let defaultBackendBaseURL = "http://192.168.0.193:8010"
}
