import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'app/router/app_router.dart';
import 'app/router/routes.dart';
import 'app/theme/app_theme.dart';
import 'core/env/env.dart';
import 'core/network/auth_event.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/notification/provider/notification_providers.dart';
import 'features/notification/service/fcm_service.dart';
import 'firebase_options.dart';
import 'widget_bridge/widget_background_callback.dart';
import 'widget_bridge/widget_navigator.dart';
import 'widget_bridge/widget_publisher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 종료 상태에서 데이터 메시지 도착 시 별도 isolate 가 열린다.
  // runApp 전에 등록 필수.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  KakaoSdk.init(nativeAppKey: Env.kakaoAppKey);
  await WidgetPublisher.init();
  await registerWidgetBackgroundCallback();
  WidgetNavigator.listen();
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<void>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = authExpiredStream.listen((_) {
      ref.invalidate(isLoggedInProvider);
      appRouter.go(Routes.login);
    });
    WidgetNavigator.handleInitialLaunch();
    // 푸시 핸들러 와이어업 + 토큰 발급. 백엔드 등록(P2)은 onTokenIssued 콜백
    // 에서 후속 작업. 백엔드 미구현이어도 토큰 콘솔 출력 + 메시지 수신/라우팅 동작.
    ref.read(fcmServiceProvider).initialize();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '모아북',
      theme: appTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
