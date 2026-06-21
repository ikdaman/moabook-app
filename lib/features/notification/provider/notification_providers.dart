import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasource/notification_remote_datasource.dart';
import '../../../data/repository/notification_repository_impl.dart';
import '../../../domain/repository/notification_repository.dart';
import '../../auth/provider/auth_provider.dart';
import '../service/fcm_service.dart';
import '../service/local_notification_service.dart';
import '../service/push_routing_service.dart';

/// 푸시 알림 모듈 DI graph.
///
/// 의존 그래프:
///   PushRoutingService ─────┐
///                           ├─→ LocalNotificationService ──┐
///                           │                              ├─→ FcmService
///                           └──────────────────────────────┘
///
/// 호출 측은 `ref.read(fcmServiceProvider).initialize()` 한 번이면 전체 파이프라인 가동.

/// 현재 플랫폼 문자열 — 백엔드 계약(`platform: "ANDROID"|"IOS"`).
String currentPlatform() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

final pushRoutingServiceProvider = Provider<PushRoutingService>(
  (_) => PushRoutingService(),
);

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService(ref.watch(pushRoutingServiceProvider));
});

// ── 백엔드 알림 API ─────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRepositoryImpl(NotificationRemoteDataSource(dio));
});

final fcmServiceProvider = Provider<FcmService>((ref) {
  final svc = FcmService(
    ref.watch(localNotificationServiceProvider),
    ref.watch(pushRoutingServiceProvider),
  );
  // 토큰 발급/회전 시 백엔드에 device-token 등록.
  // 비로그인 상태에서는 등록을 건너뛴다 — 401 이 TokenRefreshInterceptor 에서
  // notifyAuthExpired() → /login 강제 이동으로 격상되어 온보딩/스플래시 흐름을
  // 끊기 때문. 로그인 성공 직후 AuthNotifier 가 resendToken() 으로 재등록한다.
  svc.onTokenIssued = (token) async {
    final loggedIn = await ref.read(authRepositoryProvider).isLoggedIn();
    if (!loggedIn) {
      debugPrint('device-token 등록 생략(비로그인)');
      return;
    }
    try {
      await ref
          .read(notificationRepositoryProvider)
          .registerDeviceToken(token, currentPlatform());
      debugPrint('device-token 등록 성공');
    } catch (e) {
      debugPrint('device-token 등록 실패(흡수): $e');
    }
  };
  return svc;
});
