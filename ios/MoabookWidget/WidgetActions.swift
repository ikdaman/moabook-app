import AppIntents
import Foundation
import WidgetKit

/// Medium widget 페이지 인덱스 저장 key (App Group UserDefaults).
enum MediumPageStore {
    static let key = "ios_medium_current_index"

    static func read() -> Int {
        UserDefaults(suiteName: WidgetCache.appGroupId)?.integer(forKey: key) ?? 0
    }

    static func write(_ value: Int) {
        UserDefaults(suiteName: WidgetCache.appGroupId)?.set(value, forKey: key)
    }
}

/// 이전 페이지 이동 — 책 개수 modulo. iOS 17+ Button(intent:) 로 호출.
struct MediumPagePrevIntent: AppIntent {
    static var title: LocalizedStringResource = "이전 페이지"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let total = WidgetCache.read().prefix(5).count
        if total == 0 { return .result() }
        let current = MediumPageStore.read()
        let next = ((current - 1) % total + total) % total
        MediumPageStore.write(next)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 다음 페이지 이동.
struct MediumPageNextIntent: AppIntent {
    static var title: LocalizedStringResource = "다음 페이지"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let total = WidgetCache.read().prefix(5).count
        if total == 0 { return .result() }
        let current = MediumPageStore.read()
        let next = (current + 1) % total
        MediumPageStore.write(next)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
