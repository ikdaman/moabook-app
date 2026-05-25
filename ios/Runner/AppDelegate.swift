import Flutter
import NaverThirdPartyLogin
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Naver Login SDK 초기화
    let naverInstance = NaverThirdPartyLoginConnection.getSharedInstance()
    naverInstance?.isNaverAppOauthEnable = true
    naverInstance?.isInAppOauthEnable = true
    naverInstance?.serviceUrlScheme = "naverlogin"
    naverInstance?.consumerKey = "HHcc6QmC3xAJOcNxFyFt"
    naverInstance?.consumerSecret = "zW0NHMQk7g"
    naverInstance?.appName = "모아북"

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Naver 로그인 콜백 처리
    NaverThirdPartyLoginConnection.getSharedInstance()?.receiveAccessToken(url)
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
