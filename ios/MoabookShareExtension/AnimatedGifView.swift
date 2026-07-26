// 번들 GIF 재생 뷰.
//
// SwiftUI 는 GIF 애니메이션을 재생하지 못하므로 ImageIO 로 프레임을
// 디코딩해 UIImageView.animationImages 로 돌린다. (외부 의존성 없음)

import ImageIO
import SwiftUI
import UIKit

struct AnimatedGifView: UIViewRepresentable {
    /// 번들 리소스 이름 (확장자 제외).
    let name: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if let (frames, duration) = Self.decodeGif(named: name) {
            view.animationImages = frames
            view.animationDuration = duration
            view.image = frames.first
            view.startAnimating()
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    private static func decodeGif(named name: String) -> ([UIImage], TimeInterval)? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "gif"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDelay(source: source, index: i)
        }
        guard !frames.isEmpty else { return nil }
        return (frames, max(duration, 0.1))
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        let defaultDelay = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return defaultDelay }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? TimeInterval
        let delay = unclamped ?? clamped ?? defaultDelay
        // 0에 가까운 지연은 브라우저 관례에 맞춰 0.1초로 보정.
        return delay < 0.02 ? defaultDelay : delay
    }
}
