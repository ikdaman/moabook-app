// 모아북 서버 저장 API + App Group 토큰 읽기.
//
// 토큰은 본앱이 lib/core/auth/shared_token_store.dart 로 미러해 둔 것을
// 읽기만 한다. 여기서 reissue 하지 않는다 — refresh token 이 회전되므로
// 확장이 갱신하면 본앱 keychain 과 어긋나(split-brain) 강제 로그아웃 위험.

import Foundation

enum MoabookApiError: Error {
    case notLoggedIn
    case server(Int)
    case network
}

enum MoabookApi {
    private static let baseUrl = "https://moabook.shop"
    private static let appGroupId = "group.shop.moabook"
    private static let accessTokenKey = "share_access_token"

    static func accessToken() -> String? {
        let token = UserDefaults(suiteName: appGroupId)?
            .string(forKey: accessTokenKey)
        return (token?.isEmpty ?? true) ? nil : token
    }

    /// '읽고 싶은 책' 저장 — historyInfo 를 생략하면 서버가 읽고 싶은 책으로
    /// 등록한다 (Dart bookSearchProvider.saveBook 과 동일 스펙).
    static func saveAsWishBook(_ book: AladinBook) async throws {
        guard let token = accessToken() else { throw MoabookApiError.notLoggedIn }

        var bookInfo: [String: Any] = [
            "source": "ALADIN",
            "aladinId": book.itemId,
            "isbn": book.isbn,
            "title": book.title,
            "author": book.author,
            "publisher": book.publisher,
            "description": book.bookDescription,
            "publishDate": book.pubDate,
            "coverImage": book.cover,
        ]
        if let totalPage = book.totalPage {
            bookInfo["totalPage"] = totalPage
        }

        var request = URLRequest(url: URL(string: "\(baseUrl)/mybooks")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["bookInfo": bookInfo])

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MoabookApiError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw MoabookApiError.network
        }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw MoabookApiError.notLoggedIn
        default: throw MoabookApiError.server(http.statusCode)
        }
    }
}
