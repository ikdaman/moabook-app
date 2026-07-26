// iOS Share Extension 과 토큰 공유용 App Group 미러.
//
// Share Extension(별도 프로세스)은 앱의 keychain(flutter_secure_storage 기본
// access group)을 읽지 못하므로, 로그인/재발급/로그아웃 시점마다
// App Group(`group.shop.moabook`) UserDefaults 에 access/refresh 토큰을
// 복사해 둔다. 확장은 읽기 전용으로만 사용하고 reissue 는 하지 않는다 —
// 서버가 refresh token 을 회전시키므로 확장이 갱신하면 본앱 keychain 과
// 어긋나(split-brain) 강제 로그아웃될 수 있기 때문.
//
// 보안 트레이드오프: App Group UserDefaults 는 평문 저장이다. keychain
// access group 공유(flutter_secure_storage IOSOptions.groupId)가 더 안전하지만
// 기존 사용자 keychain 항목 마이그레이션 리스크(로그아웃)가 있어 보류.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class SharedTokenStore {
  static const _appGroupId = 'group.shop.moabook';
  static const _accessKey = 'share_access_token';
  static const _refreshKey = 'share_refresh_token';
  static const _updatedAtKey = 'share_token_updated_at';

  /// 현재 토큰을 App Group 에 복사. iOS 외 플랫폼은 no-op.
  static Future<void> mirror(String? access, String? refresh) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<String?>(_accessKey, access);
      await HomeWidget.saveWidgetData<String?>(_refreshKey, refresh);
      await HomeWidget.saveWidgetData<int>(
        _updatedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // 미러 실패는 본 플로우(로그인 등)를 막지 않는다.
    }
  }

  /// 로그아웃/토큰 만료 시 App Group 토큰 제거.
  static Future<void> clear() => mirror(null, null);
}
