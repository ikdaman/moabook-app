import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';
import 'push_routing_service.dart';

/// FCM 초기화 + 4가지 진입점(포그라운드/백그라운드/종료/onTokenRefresh) 통합.
///
/// 백엔드 토큰 등록(`POST /notifications/device-token`)은 P2 작업 — 이 클래스는
/// 콜백만 노출한다. 백엔드 미구현이어도 토큰 발급/메시지 수신/라우팅은 동작.
class FcmService {
  FcmService(this._local, this._routing);

  final LocalNotificationService _local;
  final PushRoutingService _routing;

  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// 토큰 변경 시 외부에서 백엔드로 업로드하도록 콜백 노출. P2 작업 와이어업 지점.
  void Function(String token)? onTokenIssued;

  bool _initialized = false;

  /// 앱 시작 또는 로그인 직후 호출. 권한 요청 + 토큰 발급 + 4 핸들러 등록.
  /// 여러 번 호출되어도 부작용 없음(idempotent).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _local.initialize();

    // 1) 권한 요청 — iOS 는 실제 다이얼로그, Android 13+ 도 POST_NOTIFICATIONS 노출.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    // 2) 토큰 발급 — 콘솔에 출력해서 Firebase Console "Send test message" 검증용.
    //    iOS 시뮬레이터는 APNS 미지원 → getToken() 이 apns-token-not-set 예외를 던진다.
    //    실기기 미연결 또는 권한 거부 등 다른 일시 오류도 동일하게 흘러올 수 있어
    //    catch 로 흡수하고 다음 단계로 진행 (onTokenRefresh 가 나중에 토큰 보내줌).
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM token: $token');
        onTokenIssued?.call(token);
      }
    } catch (e) {
      debugPrint('FCM getToken 실패(무시): $e');
    }

    // 3) onTokenRefresh — 토큰 회전 시 동일 콜백 재호출.
    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((t) {
      debugPrint('FCM token refreshed: $t');
      onTokenIssued?.call(t);
    });

    // 4) 포그라운드 — 시스템이 안 그려주므로 로컬 알림으로 표시.
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('FCM onMessage: ${msg.data}');
      final notif = msg.notification;
      _local.show(
        title: notif?.title ?? msg.data['title']?.toString() ?? '모아북',
        body: notif?.body ?? msg.data['body']?.toString() ?? '',
        data: msg.data,
      );
    });

    // 5) 백그라운드 → 알림 탭 진입.
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('FCM onMessageOpenedApp: ${msg.data}');
      _routing.routeFromPayload(msg.data);
    });

    // 6) 종료 상태에서 알림 탭으로 cold-start — initState 후 한 번만 처리.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('FCM getInitialMessage: ${initial.data}');
      // 라우터가 준비된 다음 프레임에 라우팅.
      scheduleMicrotask(() => _routing.routeFromPayload(initial.data));
    }
  }

  /// 로그아웃 시 호출. 토큰 폐기 + 핸들러 해제.
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onOpenedSub = null;
    _onTokenRefreshSub = null;
    _initialized = false;
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM deleteToken 실패(무시): $e');
    }
  }
}

/// 백그라운드/종료 상태에서 시스템이 데이터 메시지를 보내면 isolate 가 따로 열린다.
/// top-level 함수 + `@pragma('vm:entry-point')` 필수.
///
/// 현재는 로깅만. 백그라운드에서 로컬 알림을 별도로 그릴 필요 없음
/// (FCM `notification` payload 가 시스템 알림으로 자동 표시).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background isolate: ${message.messageId} data=${message.data}');
}
