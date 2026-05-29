import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_providers.dart';

/// 로컬 푸시 설정 저장 키. 백엔드 미배포 시 source of truth.
const _kPushEnabled = 'push_enabled';

/// 로컬에 저장된 푸시 설정 읽기 (기본 ON). 백엔드 호출 없이 즉시 판단할 때.
Future<bool> readLocalPushEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kPushEnabled) ?? true;
}

Future<void> _writeLocalPushEnabled(bool v) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPushEnabled, v);
}

/// 푸시 알림 ON/OFF 상태 + 토글 동작.
///
/// 진입 시 `GET /notifications/settings` 시도 → 실패(백엔드 미배포/비로그인)하면
/// 로컬 저장값으로 fallback. 토글 시 로컬을 먼저 갱신(낙관적)하고 백엔드/로컬 알림
/// 사이드이펙트를 적용한다.
final pushSettingsProvider =
    AsyncNotifierProvider<PushSettingsNotifier, bool>(PushSettingsNotifier.new);

class PushSettingsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final settings = await ref
          .read(notificationRepositoryProvider)
          .getSettings();
      await _writeLocalPushEnabled(settings.pushEnabled);
      return settings.pushEnabled;
    } catch (e) {
      // 백엔드 미배포 / 비로그인 → 로컬 저장값 사용.
      debugPrint('getSettings 실패 → 로컬 fallback: $e');
      return readLocalPushEnabled();
    }
  }

  Future<void> toggle(bool enabled) async {
    // 낙관적: 로컬 + UI 먼저 반영.
    await _writeLocalPushEnabled(enabled);
    state = AsyncData(enabled);

    // 백엔드 동기화 (실패해도 흡수 — 배포 후 정상 반영).
    try {
      await ref.read(notificationRepositoryProvider).updateSettings(enabled);
    } catch (e) {
      debugPrint('updateSettings 실패(흡수): $e');
    }

    final fcm = ref.read(fcmServiceProvider);
    final local = ref.read(localNotificationServiceProvider);

    if (enabled) {
      // ON: 권한 확인 → 토큰 재발급/등록 → C 로컬 알림 예약.
      final granted = await fcm.ensurePermission();
      if (granted) {
        await fcm.resendToken();
        await local.rescheduleC();
      }
    } else {
      // OFF: 백엔드 device-token 해제 → FCM 토큰 폐기 → 모든 로컬 알림 취소.
      final token = fcm.currentToken;
      if (token != null) {
        try {
          await ref
              .read(notificationRepositoryProvider)
              .unregisterDeviceToken(token);
        } catch (e) {
          debugPrint('device-token 해제 실패(흡수): $e');
        }
      }
      await fcm.deleteToken();
      await local.cancelAll();
    }
  }
}
