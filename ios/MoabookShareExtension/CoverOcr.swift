// 책 표지 이미지에서 Vision OCR로 제목 후보를 뽑는 로직.
//
// Flutter 쪽 lib/features/cover_ocr/service/book_cover_ocr.dart 의
// 점수화(크기 60 + 위치 25 + 길이 15)와 노이즈 필터를 그대로 포팅했다.
// 동작을 바꿀 때는 양쪽을 함께 수정할 것.

import UIKit
import Vision

struct TitleCandidate {
    let text: String
    let score: Double
}

enum CoverOcr {

    /// 표지 이미지에서 제목 후보를 점수 순으로 반환. 텍스트가 없으면 빈 배열.
    static func recognize(image: UIImage) async -> [TitleCandidate] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // 영문 제목 표지 대비 en 보조 — ko 단독이면 라틴 문자 인식이 약하다.
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true
        // 번역서 원제(프랑스어 등) 오독 방지 — ko/en 힌트 위에 자동 감지 보강.
        if #available(iOS 16.0, macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgOrientation(from: image.imageOrientation)
        )
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        // Vision boundingBox 는 좌하단 원점 정규 좌표. "위에서부터의 y"로 변환해
        // Dart(위에서 아래로 증가) 점수식과 동일하게 계산한다.
        struct Line {
            let text: String
            let height: Double
            let topY: Double     // 0(맨위) ~ 1(맨아래)
            let centerY: Double
            let left: Double
            let right: Double
            var bottomY: Double { topY + height }
        }

        var lines: [Line] = []
        for obs in observations {
            guard let text = obs.topCandidates(1).first?.string else { continue }
            let box = obs.boundingBox
            lines.append(Line(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                height: box.height,
                topY: 1 - box.maxY,
                centerY: 1 - box.midY,
                left: box.minX,
                right: box.maxX
            ))
        }
        guard !lines.isEmpty else { return [] }

        // 여러 줄 제목 결합 (Dart combineAdjacentTitleLines 포팅):
        // 가장 큰 라인과 세로 인접·가로 겹침·크기 35%↑ 라인을 위아래로 이어붙인다.
        func combineAdjacentTitleLines(_ input: [Line]) -> String? {
            guard input.count >= 2,
                  let main = input.max(by: { $0.height < $1.height })
            else { return nil }

            func adjacent(_ o: Line) -> Bool {
                if o.text == main.text && o.topY == main.topY { return false }
                if o.height < main.height * 0.35 { return false }
                let gap = o.topY >= main.topY
                    ? o.topY - main.bottomY
                    : main.topY - o.bottomY
                if gap > main.height { return false }
                return min(o.right, main.right) - max(o.left, main.left) > 0
            }

            var above: Line?
            var below: Line?
            for o in input where adjacent(o) {
                if o.bottomY <= main.topY + main.height * 0.5 {
                    if above == nil || o.topY > above!.topY { above = o }
                } else if o.topY >= main.topY + main.height * 0.5 {
                    if below == nil || o.topY < below!.topY { below = o }
                }
            }
            if above == nil && below == nil { return nil }
            return [above?.text, main.text, below?.text]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }

        let maxHeight = lines.map(\.height).max() ?? 1
        let minY = lines.map(\.topY).min() ?? 0
        let maxY = lines.map { $0.topY + $0.height }.max() ?? 1
        let span = max(maxY - minY, 0.000001)

        var candidates: [TitleCandidate] = []
        for line in lines {
            if isNoise(line.text) { continue }

            // (a) 글자 크기: 가장 큰 글자 대비 비율 (0~60점)
            let sizeScore = (line.height / maxHeight) * 60
            // (b) 위치: 위쪽일수록 가산 (0~25점)
            let relY = (line.centerY - minY) / span
            let positionScore = (1 - relY) * 25
            // (c) 길이: 2~25자 15점, 26~40자 7점
            let len = line.text.filter { !$0.isWhitespace }.count
            let lengthScore: Double = (2...25).contains(len) ? 15
                : (26...40).contains(len) ? 7 : 0

            candidates.append(TitleCandidate(
                text: line.text,
                score: sizeScore + positionScore + lengthScore
            ))
        }

        var sorted = candidates.sorted { $0.score > $1.score }

        // 여러 줄 제목 결합 후보를 최우선으로 삽입 (노이즈 라인은 재료 제외).
        if let combined = combineAdjacentTitleLines(lines.filter { !isNoise($0.text) }),
           let top = sorted.first,
           !sorted.contains(where: { $0.text == combined }) {
            sorted.insert(TitleCandidate(text: combined, score: top.score + 1), at: 0)
        }
        return sorted
    }

    /// 제목이 아닐 게 거의 확실한 라인 필터 (Dart `isOcrNoiseLine` 포팅).
    private static func isNoise(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }

        func matches(_ pattern: String) -> Bool {
            t.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }

        // 가격: "18,000원", "₩18000", "값 15000"
        if matches(#"(₩|값)?\s*\d{1,3}([,\.]\d{3})+\s*원?"#) { return true }
        // ISBN / 바코드 숫자열
        if matches(#"\d{9,}"#) { return true }
        if matches(#"ISBN"#) { return true }
        // 숫자/기호만 있는 라인 (스크린샷 상태바 시계 "1:53", "154 3•" 포함)
        if matches(#"^[\d\s\-\.\|/:•%<>*]+$"#) { return true }

        // ── 스크린샷/SNS 잡동사니 (갤러리 공유 이미지 실측 기반) ──
        // 단독 토큰 라틴+숫자 혼합: 상태바 아이콘 오독 "087a05", "G1"
        if matches(#"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$"#) { return true }
        // 유저명/도메인 토큰: "travel_0photo", "elly_camping"
        if matches(#"^[A-Za-z0-9._]*[._][A-Za-z0-9._]*$"#) { return true }
        // 경과시간/카운트: "7분", "1천", "facelessowner 1일", "22시간 전"
        if matches(#"^(\S+\s+)?\d+\s*(분|시간|일|주|개월|년|천|만|억)(\s*전)?$"#) { return true }

        let cliches = ["베스트셀러", "개정판", "초판", "스테디셀러", "추천", "화제의",
                       "전국서점", "값", "정가", "바코드", "세트"]
        if cliches.contains(t) { return true }

        return false
    }

    private static func cgOrientation(
        from ui: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch ui {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
