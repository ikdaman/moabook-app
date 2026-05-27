import Foundation

/// Flutter `WidgetPublisher` 가 SharedPreferences 와 동일한 JSON 구조로 publish.
/// Android `WidgetUiBook` 과 필드 일치.
struct WidgetUiBook: Codable, Identifiable, Hashable {
    let mybookId: Int
    let title: String
    let reason: String?
    let createdDate: String

    var id: Int { mybookId }
}

enum WidgetCache {
    static let appGroupId = "group.shop.moabook"
    static let booksKey = "recent_store_books_json"
    static let maxEntries = 9

    static func read() -> [WidgetUiBook] {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return [] }
        guard let raw = defaults.string(forKey: booksKey),
              let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([WidgetUiBook].self, from: data)) ?? []
    }
}
