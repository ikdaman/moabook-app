import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/model/store_book.dart';

/// Native 위젯(Android Glance, iOS WidgetKit) 에 표시할 데이터 publish.
///
/// JSON key/포맷은 Android 원본 `WidgetCache` 와 동일 — 기존 사용자 cold-start 호환:
///   key   : `recent_store_books_json`
///   value : List<{mybookId, title, reason, createdDate}> JSON 인코딩
///
/// iOS 는 App Group `group.shop.moabook` UserDefaults 에 동일 key 로 저장.
class WidgetPublisher {
  static const String _booksKey = 'recent_store_books_json';
  static const String _lastFetchedAtKey = 'last_fetched_at';
  static const String _iOSAppGroupId = 'group.shop.moabook';
  static const int _maxEntries = 9;

  // home_widget 의 androidName 은 항상 application id 를 prepend 하므로
  // 패키지가 다른 receiver(project.side.widget.receiver.*)는 찾지 못함.
  // qualifiedAndroidName 으로 FQCN 그대로 전달해야 Class.forName 성공.
  static const List<String> _androidProviderNames = [
    'project.side.widget.receiver.SmallWidgetWhiteReceiver',
    'project.side.widget.receiver.SmallWidgetBlueReceiver',
    'project.side.widget.receiver.MediumWidgetWhiteReceiver',
    'project.side.widget.receiver.MediumWidgetBlueReceiver',
    'project.side.widget.receiver.LargeWidgetReceiver',
  ];

  // iOS Widget kind 5종 — Android receiver 와 1:1 매칭.
  // MoabookWidget.swift `MoabookWidgetKind` 와 동일하게 유지.
  static const List<String> _iOSKinds = [
    'MoabookSmallWhite',
    'MoabookSmallBlue',
    'MoabookMediumWhite',
    'MoabookMediumBlue',
    'MoabookLarge',
  ];

  /// 앱 시작 시 1회 호출.
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_iOSAppGroupId);
  }

  /// home 데이터 갱신 시마다 호출. 최대 9권 → JSON 직렬화 → SharedPreferences/App Group.
  static Future<void> publish(List<StoreBookItem> books) async {
    final entries = books.take(_maxEntries).map((b) {
      return {
        'mybookId': b.mybookId,
        'title': b.title,
        'reason': b.reason,
        'createdDate': b.createdDate,
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(_booksKey, jsonEncode(entries));
    await HomeWidget.saveWidgetData<int>(
      _lastFetchedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    await _reloadAll();
  }

  /// 로그아웃 시 호출. 위젯 캐시 비움 + 갱신.
  static Future<void> clear() async {
    await HomeWidget.saveWidgetData<String>(_booksKey, jsonEncode(<dynamic>[]));
    await _reloadAll();
  }

  /// 현재 플랫폼에 해당하는 위젯만 reload. home_widget 플러그인은
  /// `qualifiedAndroidName` 만 전달하면 iOS 분기에서 `name` 누락 에러를 던지고,
  /// `iOSName` 만 전달하면 Android 분기에서 같은 에러를 던진다.
  /// 따라서 `Platform.isAndroid`/`isIOS` 로 분기해서 적절한 인자만 보낸다.
  /// (테스트 환경 등 모바일이 아닌 경우 no-op)
  static Future<void> _reloadAll() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      for (final name in _androidProviderNames) {
        await HomeWidget.updateWidget(qualifiedAndroidName: name);
      }
    } else if (Platform.isIOS) {
      for (final kind in _iOSKinds) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
    }
  }
}

/// publish 트리거를 Riverpod 의존성 그래프에서 노출. provider 가 listen 해서 호출.
final widgetPublisherProvider = Provider<WidgetPublisher>((_) => WidgetPublisher());
