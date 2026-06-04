import Foundation

enum E360CalendarPreference: String, CaseIterable, Identifiable {
    case gregorian
    case hijri

    var id: String { rawValue }

    var calendar: Calendar {
        switch self {
        case .gregorian:
            Calendar(identifier: .gregorian)
        case .hijri:
            Calendar(identifier: .islamicUmmAlQura)
        }
    }
}

enum E360DateFormatter {
    static func matchTime(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US") // Force English locale for standard AM/PM times
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func matchDay(
        _ date: Date,
        calendarPreference: E360CalendarPreference = .gregorian,
        locale: Locale = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendarPreference.calendar
        formatter.locale = locale
        formatter.dateFormat = "EEE d MMM"
        return ArabicNumberFormatter.localized(formatter.string(from: date), locale: locale)
    }
}
