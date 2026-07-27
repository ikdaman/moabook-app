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

/// OCR 검색 쿼리 하나 (Dart OcrQuery 포팅). byKeyword 면 제목+저자 Keyword 검색.
struct OcrQuery {
    let text: String
    let byKeyword: Bool
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

    /// "손원평 지음" — 작가명 라인 확정 패턴(접미형). 제목 쿼리에서 제외.
    private static let strongAuthorLine =
        #"^([가-힣][가-힣·\s]{0,12}[가-힣])\s*(지음|지은이|옮김|엮음|그림|글|저)$"#
    /// "지은이 에이핫" — 접두형 작가 라인. 접미형과 동급 확정.
    private static let prefixAuthorLine =
        #"^(지은이|지음|글|그림|옮긴이|엮은이)\s+([가-힣][가-힣·\s]{0,12}[가-힣])$"#
    /// "김호연 장편소설" — 작가 추출하되 제목 쿼리로도 유지.
    private static let genreAuthorLine =
        #"^([가-힣][가-힣·\s]{0,12}[가-힣])\s+(장편소설|소설|산문집|시집|에세이)$"#

    private static func isAuthorOnlyLine(_ trimmed: String) -> Bool {
        firstCapture(in: trimmed, pattern: strongAuthorLine) != nil
            || firstCapture(in: trimmed, pattern: prefixAuthorLine) != nil
    }

    static func buildQueries(from candidates: [TitleCandidate]) -> [OcrQuery] {
        let texts = candidates.map(\.text)
        let author = extractAuthor(from: texts)
        let titleTexts = texts.filter {
            !isAuthorOnlyLine($0.trimmingCharacters(in: .whitespaces))
        }

        var queries: [OcrQuery] = []
        var seen = Set<String>()

        // 1) 제목+작가 결합 Keyword 쿼리 — 상위 2개 제목 후보의 정제본 기준.
        //    외국어 원제가 상위를 차지하는 표지(번역서) 대비, 상위권 첫 한글
        //    후보도 결합 대상에 추가한다.
        if let author {
            var combineSources = Array(titleTexts.prefix(2))
            if let hangul = titleTexts.prefix(candidateCount).first(where: {
                $0.range(of: #"[가-힣]"#, options: .regularExpression) != nil
                    && !combineSources.contains($0)
            }) {
                combineSources.append(hangul)
            }
            for raw in combineSources {
                // 장르 패턴 라인("김호연 장편소설")은 결합 기반으로 부적절.
                if firstCapture(in: raw.trimmingCharacters(in: .whitespaces),
                                pattern: genreAuthorLine) != nil { continue }
                let vs = variants(of: raw)
                guard let title = vs.last, title != author else { continue }
                let combined = "\(title) \(author)"
                if seen.insert(combined).inserted && queries.count < maxQueries {
                    queries.append(OcrQuery(text: combined, byKeyword: true))
                }
            }
        }

        // 2) 제목 단독 쿼리.
        for raw in titleTexts.prefix(candidateCount) {
            for variant in variants(of: raw) {
                if seen.insert(variant).inserted {
                    queries.append(OcrQuery(text: variant, byKeyword: false))
                    if queries.count >= maxQueries { return queries }
                }
            }
        }
        return queries
    }

    /// OCR 후보 전체에서 작가명 추출 (작가 라인은 점수 하위로 밀리기 쉬워
    /// candidateCount 제한 없이 훑는다). Dart extractOcrAuthor 포팅.
    private static func extractAuthor(from texts: [String]) -> String? {
        for raw in texts {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if let name = firstCapture(in: t, pattern: strongAuthorLine)
                ?? firstCapture(in: t, pattern: prefixAuthorLine, group: 2)
                ?? firstCapture(in: t, pattern: genreAuthorLine) {
                return name.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// 정규식 캡처 그룹 반환. 미매칭이면 nil.
    private static func firstCapture(
        in text: String, pattern: String, group: Int = 1
    ) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges > group,
            let range = Range(match.range(at: group), in: text)
        else { return nil }
        return String(text[range])
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
    static func search(queries: [OcrQuery]) async -> (books: [AladinBook], allFailed: Bool) {
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

    private static func searchByTitle(_ query: OcrQuery) async throws -> [AladinBook] {
        var components = URLComponents(string: "\(baseUrl)/ttb/api/ItemSearch.aspx")!
        components.queryItems = [
            URLQueryItem(name: "ttbkey", value: ttbKey),
            URLQueryItem(name: "query", value: query.text),
            URLQueryItem(name: "queryType", value: query.byKeyword ? "Keyword" : "Title"),
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
