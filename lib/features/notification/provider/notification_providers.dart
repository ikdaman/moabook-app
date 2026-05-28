import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final pushRoutingServiceProvider = Provider<PushRoutingService>(
  (_) => PushRoutingService(),
);

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService(ref.watch(pushRoutingServiceProvider));
});

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    ref.watch(localNotificationServiceProvider),
    ref.watch(pushRoutingServiceProvider),
  );
});
