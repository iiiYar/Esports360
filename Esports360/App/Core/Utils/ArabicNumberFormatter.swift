import Foundation

enum ArabicNumberFormatter {
    static func localized(_ value: Int, locale: Locale = .current) -> String {
        String(value)
    }

    static func localized(_ value: Double, maxFractionDigits: Int = 1, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US") // Force English digits and formatting globally
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func localized(_ string: String, locale: Locale = .current) -> String {
        let westernDigits: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]
        return String(string.map { westernDigits[$0] ?? $0 })
    }
}
