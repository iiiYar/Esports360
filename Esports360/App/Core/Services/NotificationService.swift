import Foundation
import UserNotifications

enum NotificationCategoryIdentifier {
    static let match = "MATCH_UPDATES"
    static let fantasy = "FANTASY_REMINDERS"
}

enum NotificationActionIdentifier {
    static let openMatch = "OPEN_MATCH"
    static let muteTeam = "MUTE_TEAM"
    static let editLineup = "EDIT_LINEUP"
}

actor NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func configureCategories() {
        let openMatch = UNNotificationAction(
            identifier: NotificationActionIdentifier.openMatch,
            title: String(localized: "notification.action.openMatch"),
            options: [.foreground]
        )
        let muteTeam = UNNotificationAction(
            identifier: NotificationActionIdentifier.muteTeam,
            title: String(localized: "notification.action.muteTeam"),
            options: []
        )
        let editLineup = UNNotificationAction(
            identifier: NotificationActionIdentifier.editLineup,
            title: String(localized: "notification.action.editLineup"),
            options: [.foreground]
        )

        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.match,
                actions: [openMatch, muteTeam],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: NotificationCategoryIdentifier.fantasy,
                actions: [editLineup],
                intentIdentifiers: []
            )
        ])
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleMatchReminder(match: Match, minutesBeforeStart: Int = 15) async throws {
        guard let beginAt = match.beginAt else { return }

        let reminderDate = beginAt.addingTimeInterval(TimeInterval(-minutesBeforeStart * 60))
        guard reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.matchStart.title")
        content.body = String(
            format: String(localized: "notification.matchStart.body"),
            match.firstTeam?.displayName ?? "TBD",
            match.secondTeam?.displayName ?? "TBD"
        )
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.match
        content.userInfo = ["matchID": match.id]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let request = UNNotificationRequest(
            identifier: "match-start-\(match.id)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )

        try await center.add(request)
    }

    func cancelMatchReminder(match: Match) {
        center.removePendingNotificationRequests(withIdentifiers: ["match-start-\(match.id)"])
    }
}
