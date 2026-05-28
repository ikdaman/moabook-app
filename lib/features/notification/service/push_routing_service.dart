import 'package:flutter/foundation.dart';

import '../../../app/router/app_router.dart';
import '../../../app/router/routes.dart';

/// 푸시 payload 의 `type` 필드로 deep link 라우팅을 결정.
///
/// 설계 문서 매핑:
///   type=A             → `/barcode` (이번 달 추천 등 외부 검색 진입)
///   type=B + mybookId  → `/main/book-info/{mybookId}` (특정 책 상세)
///   type=C 또는 unknown → `/main/home` (기본)
///
/// FCM `onMessageOpenedApp`, `getInitialMessage`, 로컬 알림 탭 콜백
/// 3가지 진입점에서 동일 함수를 호출한다.
class PushRoutingService {
  /// payload → 경로 결정. 호출자가 [pop]/[push] 정책을 별도로 적용하지 않도록
  /// 라우팅까지 직접 수행.
  void routeFromPayload(Map<String, dynamic> data) {
    final route = resolvePath(data);
    debugPrint('PushRoutingService → $route (payload=$data)');
    appRouter.go(route);
  }

  /// payload 만 받아 결과 경로 문자열 반환 — 단위 테스트용 순수 함수.
  static String resolvePath(Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.toUpperCase();
    switch (type) {
      case 'A':
        return Routes.barcode;
      case 'B':
        final id = _parseInt(data['mybookId']);
        if (id != null) return Routes.bookInfo(id);
        return Routes.home;
      case 'C':
      default:
        return Routes.home;
    }
  }

  static int? _parseInt(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
