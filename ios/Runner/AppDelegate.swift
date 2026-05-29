import FirebaseCore
import FirebaseMessaging
import Flutter
import NidThirdPartyLogin
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    // 신형 엔진 델리게이트 구조에서 firebase swizzling 이 APNs 등록을 안 거는 경우가 있어
    // 명시적으로 원격 알림 등록을 호출한다. (Dart 권한 요청과 별개로 항상 등록 시도)
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs 가 디바이스 토큰을 내려주면 FCM 에 직접 전달. swizzling 미작동 대비 명시 전달.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("APNS deviceToken received (\(deviceToken.count) bytes)")
    // APNs 환경 명시. 자동감지(.unknown)나 #if DEBUG 매크로는 빌드 설정에 따라
    // prod 로 잘못 판정될 수 있다. 실제 서명에 박힌 aps-environment 를 런타임에
    // 읽어 sandbox/prod 를 확정한다. (잘못되면 푸시가 무성으로 드랍됨)
    let apnsType = Self.detectAPNSTokenType()
    Messaging.messaging().setAPNSToken(deviceToken, type: apnsType)
    print("APNS token type set: \(apnsType == .sandbox ? "sandbox" : "prod")")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // 등록 실패 시 진짜 원인(entitlement/네트워크/프로비저닝)을 로그로 노출.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("APNS register FAILED: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Naver 로그인 콜백 처리 (NidOAuth 신규 방식)
    if NidOAuth.shared.handleURL(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// embedded.mobileprovision 의 aps-environment 값을 읽어 APNs 토큰 타입 결정.
  /// development → sandbox, 그 외(production)/프로파일 없음 → prod.
  /// 시뮬레이터는 프로파일이 없어 항상 sandbox 로 간주.
  private static func detectAPNSTokenType() -> MessagingAPNSTokenType {
    #if targetEnvironment(simulator)
    return .sandbox
    #else
    guard
      let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      // 프로파일은 CMS 서명된 바이너리 → .ascii 는 127 초과 바이트에서 nil 을 낸다.
      // .isoLatin1 은 256바이트 전부 매핑되어 내부 plist 텍스트를 안전하게 읽는다.
      let content = String(data: data, encoding: .isoLatin1),
      let keyRange = content.range(of: "<key>aps-environment</key>")
    else {
      return .prod
    }
    let after = content[keyRange.upperBound...]
    guard
      let open = after.range(of: "<string>"),
      let close = after[open.upperBound...].range(of: "</string>")
    else {
      return .prod
    }
    let value = after[open.upperBound..<close.lowerBound]
    return value.contains("development") ? .sandbox : .prod
    #endif
  }
}
