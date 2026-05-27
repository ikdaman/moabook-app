import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/dio_client.dart';
import '../data/datasource/mybook_datasource.dart';
import 'widget_publisher.dart';

/// Android Glance Small widget refresh 버튼 → `HomeWidgetBackgroundIntent` →
/// Dart background isolate 진입점.
///
/// uri 예시: `moabookwidget://refresh_small`
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetPublisher.init();

  if (uri.host == 'refresh_small') {
    await _refreshStoreBooks();
  }
}

Future<void> _refreshStoreBooks() async {
  try {
    final dio = createDioClient(const FlutterSecureStorage());
    final ds = MyBookDataSourceImpl(dio);
    final page = await ds.getStoreBooks(page: 0, size: 9, descending: true);
    await WidgetPublisher.publish(page.content);
  } catch (_) {
    // 실패해도 무시: 위젯은 기존 캐시 그대로 유지.
  }
}

/// main() 에서 1회 호출. background callback 등록.
Future<void> registerWidgetBackgroundCallback() async {
  await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
}
