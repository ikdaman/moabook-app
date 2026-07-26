// Share Extension 진입점.
//
// Photos 등에서 이미지 공유 → 모아북 선택 시 시스템이 이 VC를 띄운다.
// NSItemProvider 에서 이미지를 꺼내 다운스케일 후 ShareFlowModel 로 넘기고,
// SwiftUI 시트(ShareSheetView)를 투명 배경 위에 호스팅한다.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    /// 확장 메모리 한도(~120MB) 대비 최대 변 제한.
    private static let maxImageDimension: CGFloat = 2000

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

    private func loadSharedImage() {
        let provider = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard let provider else {
            model.start(image: nil)
            return
        }

        provider.loadItem(
            forTypeIdentifier: UTType.image.identifier, options: nil
        ) { [weak self] item, _ in
            guard let self else { return }
            let image = Self.extractImage(from: item)
            DispatchQueue.main.async {
                self.model.start(image: image.map(Self.downscaled))
            }
        }
    }

    private static func extractImage(from item: NSSecureCoding?) -> UIImage? {
        switch item {
        case let url as URL:
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        case let data as Data:
            return UIImage(data: data)
        case let image as UIImage:
            return image
        default:
            return nil
        }
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxImageDimension else { return image }
        let scale = maxImageDimension / maxSide
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
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
