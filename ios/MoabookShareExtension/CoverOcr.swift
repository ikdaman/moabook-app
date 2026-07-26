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
        request.recognitionLanguages = ["ko-KR"]
        request.usesLanguageCorrection = true

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
        }

        var lines: [Line] = []
        for obs in observations {
            guard let text = obs.topCandidates(1).first?.string else { continue }
            let box = obs.boundingBox
            lines.append(Line(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                height: box.height,
                topY: 1 - box.maxY,
                centerY: 1 - box.midY
            ))
        }
        guard !lines.isEmpty else { return [] }

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

        return candidates.sorted { $0.score > $1.score }
    }

    /// 제목이 아닐 게 거의 확실한 라인 필터 (Dart `_isNoise` 포팅).
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
        // 숫자/기호만 있는 라인
        if matches(#"^[\d\s\-\.\|/]+$"#) { return true }

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
