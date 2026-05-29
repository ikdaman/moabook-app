import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'push_routing_service.dart';

/// 포그라운드 푸시 + 로컬 알림 표시 wrapper.
///
/// FCM `onMessage` (포그라운드) 는 시스템이 자동으로 알림을 그리지 않으므로
/// 직접 `flutter_local_notifications` 로 렌더링한다. 백그라운드/종료 상태는
/// 시스템이 그리므로 이 클래스는 포그라운드/로컬 알림만 담당.
///
/// payload(JSON 문자열) — FCM data 필드 그대로 전달. 탭 시 [PushRoutingService]
/// 가 받아 라우팅한다.
class LocalNotificationService {
  LocalNotificationService(this._routing);

  final PushRoutingService _routing;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'moabook_default',
    '모아북 알림',
    description: '읽고 싶은 책 / 신규 기능 / 일반 푸시',
    importance: Importance.high,
  );

  /// C(재방문 유도) 로컬 알림 고정 ID — 재예약 시 항상 이 ID 로 덮어쓴다.
  static const cNotificationId = 7001;

  /// 마지막 앱 진입 후 이 기간이 지나면 C 알림 발동. (검증 시 짧게 바꿔 테스트)
  static const _cDelay = Duration(days: 7);

  /// C 알림 문구 (설계 문서 7.3) — 예약 시 랜덤 1개 선택.
  static const _cMessages = [
    '요즘 읽고 싶은 책은 없으세요? 새로운 책을 담아보세요',
    '오랜만에 내 서점 구경 어때요',
    '내 서점에 먼지가 쌓이고 있어요…',
  ];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // FCM 가 권한 요청을 담당하므로 여기서는 요청하지 않는다.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Android 채널 생성 — 시스템 설정 화면에서 사용자가 끌 수 있는 단위.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  /// FCM `onMessage` 콜백에서 호출. data 만 사용, notification 필드는 무시
  /// (서버가 항상 data-only push 를 보낸다는 백엔드 계약 가정).
  Future<void> show({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      'moabook_default',
      '모아북 알림',
      channelDescription: '읽고 싶은 책 / 신규 기능 / 일반 푸시',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      // millis 하위 31bit → Android notification id (Int32 범위).
      DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  /// C(재방문 유도) 알림 재예약. 앱 foreground 진입(`resumed`) 시마다 호출.
  /// 기존 예약을 취소하고 [_cDelay] 뒤로 새로 잡는다 → 진입할 때마다 7일 뒤로 밀림.
  Future<void> rescheduleC() async {
    await initialize();
    await _plugin.cancel(cNotificationId);

    final when = tz.TZDateTime.now(tz.local).add(_cDelay);
    final body = _cMessages[Random().nextInt(_cMessages.length)];

    const androidDetails = AndroidNotificationDetails(
      'moabook_default',
      '모아북 알림',
      channelDescription: '읽고 싶은 책 / 신규 기능 / 일반 푸시',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      cNotificationId,
      '모아북',
      body,
      when,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 재방문 유도라 정확한 시각 불필요 → 정확 알람 권한(SCHEDULE_EXACT_ALARM) 회피.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(const {'type': 'C'}),
    );
    debugPrint('LocalNotification C 예약: $when / "$body"');
  }

  /// C 예약만 취소.
  Future<void> cancelC() async {
    await initialize();
    await _plugin.cancel(cNotificationId);
  }

  /// 모든 로컬 알림 취소 (로그아웃 / 푸시 OFF).
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  void _onTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _routing.routeFromPayload(decoded.cast<String, dynamic>());
    } catch (e, st) {
      debugPrint('LocalNotificationService payload decode 실패: $e\n$st');
    }
  }
}
