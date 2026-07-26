import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'app/router/app_router.dart';
import 'app/router/routes.dart';
import 'app/theme/app_theme.dart';
import 'core/auth/shared_token_store.dart';
import 'core/env/env.dart';
import 'core/network/auth_event.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/home/provider/home_provider.dart';
import 'features/notification/provider/notification_providers.dart';
import 'features/notification/provider/push_settings_provider.dart';
import 'features/notification/service/fcm_service.dart';
import 'features/share_import/share_main.dart' as share_import;
import 'firebase_options.dart';
import 'widget_bridge/widget_background_callback.dart';
import 'widget_bridge/widget_navigator.dart';
import 'widget_bridge/widget_publisher.dart';

/// 갤러리 공유(ShareActivity) 진입점. 루트 라이브러리에 있어야
/// 네이티브 쪽 entrypoint 이름 조회가 가능해 위임만 한다.
@pragma('vm:entry-point')
void shareMain() => share_import.shareMain();

/// iOS Share Extension 용 토큰 미러 (기동 시 1회).
/// 이번 버전 이전에 로그인한 유저도 재로그인 없이 공유 기능을 쓸 수 있도록
/// keychain 의 현재 토큰을 App Group 으로 복사한다. iOS 외에는 no-op.
Future<void> _mirrorTokensForShareExtension() async {
  const storage = FlutterSecureStorage();
  final access = await storage.read(key: 'access_token');
  final refresh = await storage.read(key: 'refresh_token');
  if (access != null && refresh != null) {
    await SharedTokenStore.mirror(access, refresh);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 로컬 알림 zonedSchedule 용 timezone 초기화. C 알림은 KST 기준 (설계 가정).
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 종료 상태에서 데이터 메시지 도착 시 별도 isolate 가 열린다.
  // runApp 전에 등록 필수.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  KakaoSdk.init(nativeAppKey: Env.kakaoAppKey);
  await WidgetPublisher.init();
  await _mirrorTokensForShareExtension();
  await registerWidgetBackgroundCallback();
  WidgetNavigator.listen();
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  StreamSubscription<void>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  /// 앱이 foreground 로 돌아올 때마다 C 알림을 7일 뒤로 재예약 →
  /// "마지막 진입 후 7일" 트리거 구현. 푸시 설정 OFF 면 예약하지 않는다.
  /// 홈 목록도 함께 갱신 — 공유 확장(share-import)이 앱 밖에서 책을
  /// 저장한 뒤 복귀하면 warm start 라 목록이 낡아 있기 때문.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rescheduleCIfEnabled();
      if (ref.read(isLoggedInProvider).valueOrNull == true) {
        ref.read(homeProvider.notifier).load();
      }
    }
  }

  Future<void> _rescheduleCIfEnabled() async {
    if (await readLocalPushEnabled()) {
      await ref.read(localNotificationServiceProvider).rescheduleC();
    }
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
