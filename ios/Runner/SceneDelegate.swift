import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // iOS 26 에서 scene 상태복원 저장 경로(_saveSceneRestorationState)가
  // SwiftUI 내부 assert 를 유발해 앱 업데이트 첫 실행 시 EXC_BREAKPOINT 로 죽는 문제 회피.
  // 이 앱은 Flutter RestorationMixin/restorationScopeId 를 쓰지 않아 복원할 상태가 없으므로
  // nil 을 반환해 scene 복원 활동 저장 자체를 비활성화한다. (기능 손실 없음)
  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    return nil
  }
}
