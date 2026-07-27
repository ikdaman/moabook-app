// Share Extension 진입점.
//
// Photos 등에서 이미지 공유 → 모아북 선택 시 시스템이 이 VC를 띄운다.
// NSItemProvider 에서 이미지를 꺼내 다운스케일 후 ShareFlowModel 로 넘기고,
// SwiftUI 시트(ShareSheetView)를 투명 배경 위에 호스팅한다.

import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    /// 확장 메모리 한도(~120MB) 대비 최대 변 제한.
    /// CGImageSource 다운샘플은 원본 전체를 디코드하지 않아 3000px도 안전.
    private static let maxImageDimension: CGFloat = 3000

    private let model = ShareFlowModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(
            rootView: ShareSheetView(
                model: model,
                onClose: { [weak self] in self?.complete() },
                onOpenApp: { [weak self] in self?.openMainApp() }
            )
        )
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)

        loadSharedImage()
    }

    // ── 이미지 수신 ───────────────────────────────────────────────────────

    /// Live Photo 는 loadItem(public.image) 이 PHLivePhoto 를 넘기려다
    /// (확장은 Photos 를 링크하지 않아) 디코드 예외로 즉사한다.
    /// loadFileRepresentation 은 항상 정지 이미지 파일 URL 을 주므로 안전.
    private func loadSharedImage() {
        let provider = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard let provider else {
            model.start(image: nil)
            return
        }

        provider.loadFileRepresentation(
            forTypeIdentifier: UTType.image.identifier
        ) { [weak self] url, _ in
            // URL 은 이 핸들러 동안만 유효 — 여기서 바로 다운샘플한다.
            let image = url.flatMap { Self.downsampledImage(at: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                if let image {
                    self.model.start(image: image)
                } else {
                    self.loadInMemoryImage(from: provider)
                }
            }
        }
    }

    /// 파일 표현이 없는 소스(드물게 UIImage/Data 만 주는 앱) 폴백.
    private func loadInMemoryImage(from provider: NSItemProvider) {
        _ = provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            let image = (object as? UIImage).flatMap { image -> UIImage? in
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    return nil
                }
                return Self.downsampledImage(from: data)
            }
            DispatchQueue.main.async {
                self?.model.start(image: image)
            }
        }
    }

    // ── 다운샘플 ─────────────────────────────────────────────────────────
    // 원본 전체 디코드 없이 타깃 크기로 바로 디코드해 메모리 스파이크를 피한다.
    // (UIGraphicsImageRenderer 방식은 24MP+ 사진에서 확장 한도를 넘겨 jetsam 킬.)

    private static func downsampledImage(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return downsampledImage(from: source)
    }

    private static func downsampledImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return downsampledImage(from: source)
    }

    private static func downsampledImage(from source: CGImageSource) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,  // EXIF 회전 반영
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImageDimension,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // ── 종료/앱 열기 ──────────────────────────────────────────────────────

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 확장에서는 UIApplication.shared 접근이 막혀 있어 responder chain 을
    /// 타고 올라가 openURL: 을 찾는 통상적인 방식으로 본앱을 연다.
    /// `moabookwidget://home` 은 기존 위젯 탭 경로 — WidgetNavigator 가
    /// cold/warm start 모두 홈으로 라우팅한다.
    private func openMainApp() {
        guard let url = URL(string: "moabookwidget://home") else {
            complete()
            return
        }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            if current.responds(to: Selector(("openURL:"))) {
                current.perform(Selector(("openURL:")), with: url)
                break
            }
            responder = current.next
        }
        complete()
    }
}
