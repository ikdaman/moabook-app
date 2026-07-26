// 공유 플로우 상태 머신: 이미지 수신 → OCR → 알라딘 검색 → 선택 → 저장.
// Flutter 쪽 share_import_provider.dart 와 동일한 단계/오류 구분을 유지한다.

import Combine
import UIKit

@MainActor
final class ShareFlowModel: ObservableObject {
    enum Step { case loading, pickBook, saved, error }
    enum ErrorKind { case imageFailed, noText, noResult, network, notLoggedIn }

    @Published var step: Step = .loading
    @Published var errorKind: ErrorKind = .network
    @Published var results: [AladinBook] = []
    @Published var savedBook: AladinBook?
    @Published var isSaving = false

    func fail(_ kind: ErrorKind) {
        errorKind = kind
        step = .error
    }

    func start(image: UIImage?) {
        Task {
            guard let image else {
                fail(.imageFailed)
                return
            }
            guard MoabookApi.accessToken() != nil else {
                fail(.notLoggedIn)
                return
            }

            let candidates = await CoverOcr.recognize(image: image)
            guard !candidates.isEmpty else {
                fail(.noText)
                return
            }

            let queries = AladinClient.buildQueries(from: candidates)
            let (books, allFailed) = await AladinClient.search(queries: queries)
            if books.isEmpty {
                // 전 쿼리 실패면 결과 없음이 아니라 네트워크 문제로 안내.
                fail(allFailed && !queries.isEmpty ? .network : .noResult)
                return
            }

            results = books
            step = .pickBook
        }
    }

    /// 책 탭 → 즉시 '읽고 싶은 책' 저장.
    func save(_ book: AladinBook) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await MoabookApi.saveAsWishBook(book)
                savedBook = book
                step = .saved
            } catch MoabookApiError.notLoggedIn {
                fail(.notLoggedIn)
            } catch {
                fail(.network)
            }
        }
    }
}
