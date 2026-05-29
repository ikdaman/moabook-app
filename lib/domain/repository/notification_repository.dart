import '../model/push_settings.dart';

/// 알림 토큰 등록/해제 + 설정 조회/변경.
///
/// 순수 인터페이스 — 구현은 백엔드 호출만 수행하고 오류를 그대로 전파한다.
/// graceful fallback(백엔드 미배포 시 로컬 상태 사용)은 provider 계층 책임.
abstract interface class NotificationRepository {
  Future<void> registerDeviceToken(String fcmToken, String platform);
  Future<void> unregisterDeviceToken(String fcmToken);
  Future<PushSettings> getSettings();
  Future<PushSettings> updateSettings(bool enabled);
}
