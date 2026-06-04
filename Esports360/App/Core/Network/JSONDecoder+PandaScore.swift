import Foundation

extension JSONDecoder {
    static var pandaScore: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            // 1. Try standard ISO8601 formatters (3-digit fractional or 0-digit)
            if let date = ISO8601DateFormatter.pandaScoreWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.pandaScore.date(from: value) {
                return date
            }

            // 2. Try fallback for python datetime.isoformat() with 6 digits fractional seconds
            // e.g., "2026-05-27T08:14:10.133983+00:00"
            let microsecondFormatter = DateFormatter()
            microsecondFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            microsecondFormatter.locale = Locale(identifier: "en_US_POSIX")
            microsecondFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = microsecondFormatter.date(from: value) {
                return date
            }

            // 3. Try standard DateFormatter with 3 digits fractional seconds
            let millisecondFormatter = DateFormatter()
            millisecondFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            millisecondFormatter.locale = Locale(identifier: "en_US_POSIX")
            millisecondFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = millisecondFormatter.date(from: value) {
                return date
            }

            // 4. Try parsing manually by standardizing fractional seconds to exactly 3 digits
            // e.g. "2026-05-27T08:14:10.133983+00:00" -> "2026-05-27T08:14:10.133+00:00"
            if let dotIndex = value.firstIndex(of: ".") {
                let prefix = value[..<dotIndex]
                let suffix = value[dotIndex...]
                if let tzIndex = suffix.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
                    let tzPart = suffix[tzIndex...]
                    var fractionPart = suffix[..<tzIndex]
                    if fractionPart.count > 4 {
                        fractionPart = fractionPart.prefix(4)
                    } else {
                        while fractionPart.count < 4 {
                            fractionPart.append("0")
                        }
                    }
                    let cleanedValue = String(prefix) + String(fractionPart) + String(tzPart)
                    if let date = ISO8601DateFormatter.pandaScoreWithFractionalSeconds.date(from: cleanedValue) {
                        return date
                    }
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    static let pandaScore: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let pandaScoreWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
