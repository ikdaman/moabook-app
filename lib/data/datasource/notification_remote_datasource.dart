import 'package:dio/dio.dart';

import '../model/push_settings_model.dart';

/// 알림 백엔드 API 클라이언트.
///
/// 계약(백엔드 설계 문서 `2026-05-28-push-notification-backend-design.md`):
///   POST   /notifications/device-token   { fcmToken, platform: "ANDROID"|"IOS" } → 200
///   DELETE /notifications/device-token   { fcmToken }                            → 204
///   GET    /notifications/settings                                               → { pushEnabled }
///   PATCH  /notifications/settings        { pushEnabled }                         → { pushEnabled }
///
/// 인증 인터셉터가 자동으로 `Authorization` 을 붙인다(로그인 상태 전제).
/// 순수 클라이언트 — 오류 흡수는 호출 측(provider)에서 처리.
class NotificationRemoteDataSource {
  final Dio _dio;

  NotificationRemoteDataSource(this._dio);

  Future<void> registerDeviceToken(String fcmToken, String platform) async {
    await _dio.post<void>(
      '/notifications/device-token',
      data: {'fcmToken': fcmToken, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String fcmToken) async {
    await _dio.delete<void>(
      '/notifications/device-token',
      data: {'fcmToken': fcmToken},
    );
  }

  Future<PushSettingsModel> getSettings() async {
    final r = await _dio.get<Map<String, dynamic>>('/notifications/settings');
    return PushSettingsModel.fromJson(r.data ?? const {});
  }

  Future<PushSettingsModel> updateSettings(bool enabled) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/notifications/settings',
      data: {'pushEnabled': enabled},
    );
    return PushSettingsModel.fromJson(r.data ?? {'pushEnabled': enabled});
  }
}
