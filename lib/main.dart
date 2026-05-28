import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'app/router/app_router.dart';
import 'app/router/routes.dart';
import 'app/theme/app_theme.dart';
import 'core/env/env.dart';
import 'core/network/auth_event.dart';
import 'features/auth/provider/auth_provider.dart';
import 'widget_bridge/widget_background_callback.dart';
import 'widget_bridge/widget_navigator.dart';
import 'widget_bridge/widget_publisher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
