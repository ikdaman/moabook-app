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

/// Small widget 현재 mybookId. 0 이면 미설정 (books.first 사용).
enum SmallCurrentStore {
    static let mybookIdKey = "ios_small_current_mybook_id"

    static func read() -> Int {
        UserDefaults(suiteName: WidgetCache.appGroupId)?.integer(forKey: mybookIdKey) ?? 0
    }

    static func write(_ value: Int) {
        UserDefaults(suiteName: WidgetCache.appGroupId)?.set(value, forKey: mybookIdKey)
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

/// Small widget 새로고침 — cache 에서 현재 책 제외하고 다른 책 1권 랜덤 픽.
/// 서버 fetch 안 함. 앱 안 열림.
struct RefreshSmallIntent: AppIntent {
    static var title: LocalizedStringResource = "새로고침"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let books = WidgetCache.read()
        guard !books.isEmpty else { return .result() }

        let currentMybookId = SmallCurrentStore.read()
        let candidates = books.filter { $0.mybookId != currentMybookId }
        let pool = candidates.isEmpty ? books : candidates
        if let picked = pool.randomElement() {
            SmallCurrentStore.write(picked.mybookId)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
