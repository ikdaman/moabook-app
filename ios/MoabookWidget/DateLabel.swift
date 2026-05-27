import Foundation

/// Android `project.side.widget.domain.DateLabel` 동등.
enum DateLabel {
    private static let dustThresholdDays = 100
    private static let dustMessage = "책에 먼지가 쌓였어요..."
    private static let todayLabel = "오늘 저장"

    static func format(_ createdDate: String, today: Date = Date()) -> String {
        guard let parsed = parseDate(createdDate) else { return todayLabel }
        let calendar = Calendar(identifier: .gregorian)
        let startToday = calendar.startOfDay(for: today)
        let startParsed = calendar.startOfDay(for: parsed)
        let daysSince = calendar.dateComponents([.day], from: startParsed, to: startToday).day ?? 0
        switch daysSince {
        case ..<1: return todayLabel
        case 1...dustThresholdDays: return "\(daysSince)일 전 저장"
        default: return dustMessage
        }
    }

    static func formatDisplay(_ createdDate: String) -> String {
        guard let parsed = parseDate(createdDate) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: parsed)
    }

    private static func parseDate(_ input: String) -> Date? {
        let datePart = String(input.split(separator: "T").first ?? "").trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: datePart)
    }
}
