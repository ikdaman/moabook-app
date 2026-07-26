// 알라딘 ItemSearch 호출 + OCR 후보 → 쿼리 변환 + 결과 병합.
//
// Flutter 쪽 lib/features/cover_ocr/service/cover_ocr_search.dart 와
// lib/data/datasource/aladin_datasource.dart 의 포팅. 동작 변경 시 양쪽 동기화.

import Foundation

struct AladinBook: Identifiable {
    let title: String
    let author: String
    let cover: String
    let publisher: String
    let isbn: String
    let itemId: Int
    let link: String
    let bookDescription: String
    let pubDate: String
    let totalPage: Int?

    var id: Int { itemId }
}

enum AladinClient {
    private static let baseUrl = "https://www.aladin.co.kr"
    private static let ttbKey = "ttbgju060611831003"

    /// 쿼리 생성에 사용할 상위 후보 개수 (Dart searchCandidateCount).
    private static let candidateCount = 5
    /// 알라딘 호출 상한 (Dart maxQueries).
    private static let maxQueries = 8
    /// 쿼리별 상위 결과 수 (Dart _perQueryLimit).
    private static let perQueryLimit = 10

    // ── 쿼리 생성 (Dart buildOcrQueries 포팅) ─────────────────────────────

    static func buildQueries(from candidates: [TitleCandidate]) -> [String] {
        var queries: [String] = []
        var seen = Set<String>()
        for candidate in candidates.prefix(candidateCount) {
            for variant in variants(of: candidate.text) {
                if seen.insert(variant).inserted {
                    queries.append(variant)
                    if queries.count >= maxQueries { return queries }
                }
            }
        }
        return queries
    }

    /// 원문 + 정제 변형 (괄호 안 부가정보/장식 기호 제거).
    private static func variants(of raw: String) -> [String] {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return [] }
        var out = [t]

        var cleaned = t
        func replace(_ pattern: String, with replacement: String) {
            cleaned = cleaned.replacingOccurrences(
                of: pattern, with: replacement, options: .regularExpression)
        }
        // 괄호류 안 내용 제거: (…) （…） 【…】 [...]
        replace(#"[（(【\[][^）)】\]]*[)）】\]]?"#, with: " ")
        // 한글 따옴표/겹화살괄호 제거
        replace(#"[『』「」《》〈〉]"#, with: " ")
        // 일반 따옴표 제거
        replace(#"["'`]"#, with: " ")
        // 장식 기호 제거
        replace(#"[·•\-–—_/\\]"#, with: " ")
        replace(#"\s+"#, with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        if cleaned.count >= 2 && cleaned != t { out.append(cleaned) }
        return out
    }

    // ── 검색 + 병합 ───────────────────────────────────────────────────────

    /// 쿼리들을 병렬 호출해 라운드로빈 병합 결과와 "전부 실패" 여부를 반환.
    static func search(queries: [String]) async -> (books: [AladinBook], allFailed: Bool) {
        guard !queries.isEmpty else { return ([], false) }

        var resultLists = [[AladinBook]](repeating: [], count: queries.count)
        var failures = 0

        await withTaskGroup(of: (Int, [AladinBook]?).self) { group in
            for (i, query) in queries.enumerated() {
                group.addTask { (i, try? await searchByTitle(query)) }
            }
            for await (i, books) in group {
                if let books {
                    resultLists[i] = books
                } else {
                    failures += 1
                }
            }
        }

        return (merge(resultLists), failures == queries.count)
    }

    /// 라운드로빈 병합 (Dart mergeCoverSearchResults 포팅) — 각 쿼리의
    /// N위끼리 한 바퀴씩 돌며 뽑아 정확히 맞은 책이 상단에 오게 한다.
    private static func merge(_ resultLists: [[AladinBook]]) -> [AladinBook] {
        let capped = resultLists.map { Array($0.prefix(perQueryLimit)) }
        let maxLen = capped.map(\.count).max() ?? 0

        var seen = Set<Int>()
        var merged: [AladinBook] = []
        for col in 0..<maxLen {
            for list in capped where col < list.count {
                let book = list[col]
                if seen.insert(book.itemId).inserted {
                    merged.append(book)
                }
            }
        }
        return merged
    }

    private static func searchByTitle(_ query: String) async throws -> [AladinBook] {
        var components = URLComponents(string: "\(baseUrl)/ttb/api/ItemSearch.aspx")!
        components.queryItems = [
            URLQueryItem(name: "ttbkey", value: ttbKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "queryType", value: "Title"),
            URLQueryItem(name: "cover", value: "Big"),
            URLQueryItem(name: "output", value: "js"),
            URLQueryItem(name: "version", value: "20131101"),
            URLQueryItem(name: "maxResults", value: "50"),
            URLQueryItem(name: "start", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["item"] as? [[String: Any]] ?? []
        return items.map { m in
            let subInfo = m["subInfo"] as? [String: Any]
            let pageStr = (subInfo?["itemPage"]).map { "\($0)" }
            return AladinBook(
                title: decodeHtml(m["title"] as? String ?? ""),
                author: decodeHtml(m["author"] as? String ?? ""),
                cover: m["cover"] as? String ?? "",
                publisher: decodeHtml(m["publisher"] as? String ?? ""),
                isbn: m["isbn13"] as? String ?? m["isbn"] as? String ?? "",
                itemId: (m["itemId"] as? NSNumber)?.intValue ?? 0,
                link: m["link"] as? String ?? "",
                bookDescription: decodeHtml(m["description"] as? String ?? ""),
                pubDate: m["pubDate"] as? String ?? "",
                totalPage: pageStr.flatMap { Int($0) }
            )
        }
    }

    /// 알라딘 응답의 대표적인 HTML 엔티티만 복원.
    private static func decodeHtml(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
