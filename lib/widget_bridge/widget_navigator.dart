import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../app/router/app_router.dart';
import '../app/router/routes.dart';

/// 위젯에서 refresh 신호가 들어왔을 때 broadcast. home_provider 가 listen.
final widgetRefreshStream = StreamController<void>.broadcast();

/// 위젯 탭으로 앱 진입 시 라우팅 처리.
///
/// 1. cold start: `initiallyLaunchedFromHomeWidget()` 로 최초 Uri 1회 처리
/// 2. warm start: `widgetClicked` Stream listen
class WidgetNavigator {
  static Future<void> handleInitialLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _route(uri);
  }

  static void listen() {
    HomeWidget.widgetClicked.listen(_route);
  }

  static void _route(Uri? uri) {
    if (uri == null) return;
    switch (uri.host) {
      case 'book':
        final idStr = uri.queryParameters['id'];
        final id = int.tryParse(idStr ?? '');
        if (id != null) {
          appRouter.go(Routes.bookInfo(id));
        }
        break;
      case 'home':
        appRouter.go(Routes.home);
        break;
      case 'refresh_small':
        // iOS: Link 로 앱이 깨어남. home 화면 진입 + refresh 트리거.
        // Android: HomeWidgetBackgroundIntent 로 백그라운드 isolate 호출되므로
        // 이 case 는 안 옴 (단, 앱이 foreground 일 때 들어와도 안전).
        appRouter.go(Routes.home);
        widgetRefreshStream.add(null);
        break;
    }
  }
}
