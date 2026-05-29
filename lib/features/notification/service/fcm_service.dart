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

  /// 마지막으로 발급된 FCM 토큰. 로그아웃 시 백엔드 해제(unregister)용.
  String? _currentToken;
  String? get currentToken => _currentToken;

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
    //
    //    iOS: APNS 토큰은 권한 승인 후 APNs 서버에서 비동기로 도착한다. requestPermission
    //    직후 getToken() 을 바로 부르면 apns-token-not-set 이 나므로, getAPNSToken() 이
    //    값을 줄 때까지 짧게 폴링하고 넘어간다.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _waitForApnsToken();
    }

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM token: $token');
        _currentToken = token;
        onTokenIssued?.call(token);
      }
    } catch (e) {
      debugPrint('FCM getToken 실패(무시): $e');
    }

    // 3) onTokenRefresh — 토큰 회전 시 동일 콜백 재호출.
    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((t) {
      debugPrint('FCM token refreshed: $t');
      _currentToken = t;
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

  /// iOS APNS 토큰이 도착할 때까지 최대 ~3초 폴링. 시뮬레이터(영영 nil)에서는
  /// 그냥 타임아웃되고, 실기기에서는 보통 수백 ms 안에 도착한다.
  Future<void> _waitForApnsToken() async {
    const maxAttempts = 10;
    const interval = Duration(milliseconds: 300);
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final apns = await _messaging.getAPNSToken();
        if (apns != null) {
          debugPrint('APNS token ready (attempt ${i + 1})');
          return;
        }
      } catch (e) {
        debugPrint('getAPNSToken 실패(무시): $e');
      }
      await Future<void>.delayed(interval);
    }
    debugPrint('APNS token 미도착 — getToken 은 이후 onTokenRefresh 에 의존');
  }

  /// OS 알림 권한 (재)요청. 푸시 OFF→ON 전환 시 사용.
  Future<bool> ensurePermission() async {
    final s = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission(재요청): ${s.authorizationStatus}');
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// 현재 토큰을 다시 발급받아 `onTokenIssued` 재호출 — 백엔드에 (재)등록.
  /// 앱 시작 시점엔 비로그인이라 등록이 401 로 흡수되므로, 로그인 성공 직후
  /// 이걸 불러 인증된 상태로 device-token 을 등록한다. 푸시 OFF→ON 전환에도 사용.
  Future<void> resendToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _waitForApnsToken();
    }
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        onTokenIssued?.call(token);
      }
    } catch (e) {
      debugPrint('FCM resendToken 실패(무시): $e');
    }
  }

  /// FCM 토큰 폐기 (푸시 OFF / 로그아웃). 핸들러는 유지.
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _currentToken = null;
    } catch (e) {
      debugPrint('FCM deleteToken 실패(무시): $e');
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
