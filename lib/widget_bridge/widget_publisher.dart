import 'dart:convert';

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

  static const List<String> _androidProviderNames = [
    'SmallWidgetWhiteReceiver',
    'SmallWidgetBlueReceiver',
    'MediumWidgetWhiteReceiver',
    'MediumWidgetBlueReceiver',
    'LargeWidgetReceiver',
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

    // Android 5개 receiver + iOS 위젯 모두 갱신 시그널 발사.
    for (final name in _androidProviderNames) {
      await HomeWidget.updateWidget(
        androidName: name,
        iOSName: 'MoabookWidget',
      );
    }
  }

  /// 로그아웃 시 호출. 위젯 캐시 비움 + 갱신.
  static Future<void> clear() async {
    await HomeWidget.saveWidgetData<String>(_booksKey, jsonEncode(<dynamic>[]));
    for (final name in _androidProviderNames) {
      await HomeWidget.updateWidget(
        androidName: name,
        iOSName: 'MoabookWidget',
      );
    }
  }
}

/// publish 트리거를 Riverpod 의존성 그래프에서 노출. provider 가 listen 해서 호출.
final widgetPublisherProvider = Provider<WidgetPublisher>((_) => WidgetPublisher());
