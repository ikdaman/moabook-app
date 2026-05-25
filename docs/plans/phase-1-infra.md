# Phase 1: 인프라 기반 — 테마·라우터·Dio·PixelShadowBox·Riverpod

> **For agentic workers:** superpowers:subagent-driven-development 또는 superpowers:executing-plans 사용 권장.
>
> **Spec:** `docs/superpowers/specs/2026-05-25-flutter-rebuild-design.md`
> **Roadmap:** `docs/superpowers/plans/2026-05-25-flutter-rebuild-roadmap.md`
> **Phase 0 완료 기준:** `~/dev/moabook-app` 의 Phase 0 DoD 전 항목 ✓

**Goal:** Phase 2~6의 모든 화면 개발이 이 레이어 위에서 동작할 수 있도록 테마·라우팅·네트워크·핵심 UI 컴포넌트를 배치한다.

**DoD:** `flutter test` 전 통과 + `AuthInterceptorTest` green + 시뮬레이터에서 앱 실행 시 go_router 경로 변환 정상 동작

**참고 원본:**
- 컬러/타이포/스페이싱: `~/dev/moabook/ui/src/main/java/project/side/ui/theme/`
- 라우팅 구조: `~/dev/moabook/ui/src/main/java/project/side/ui/Routes.kt` + `MainScreen.kt`
- 인터셉터 로직: `~/dev/moabook/remote/src/main/java/project/side/remote/auth/`
- PixelShadowBox: `~/dev/moabook/ui/src/main/java/project/side/ui/component/PixelShadowBox.kt`

---

## pubspec.yaml 패키지 추가

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 의존성 추가**
  ```yaml
  dependencies:
    flutter:
      sdk: flutter

    # 상태관리
    flutter_riverpod: ^2.6.1
    riverpod_annotation: ^2.6.1

    # 라우팅
    go_router: ^14.8.1

    # 네트워크
    dio: ^5.7.0
    retrofit: ^4.4.1
    json_annotation: ^4.9.0

    # 저장소
    flutter_secure_storage: ^9.2.2

    # UI
    flutter_svg: ^2.0.10+1

  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^5.0.0
    build_runner: ^2.4.14
    riverpod_generator: ^2.6.2
    retrofit_generator: ^9.1.6
    json_serializable: ^6.9.4
  ```

- [ ] **Step 2: 폰트 에셋 등록 (dunggeunmo + wantedsans)**
  ```yaml
  flutter:
    assets:
      - assets/images/
    fonts:
      - family: DungGeunMo
        fonts:
          - asset: assets/fonts/dunggeunmo.ttf
      - family: WantedSans
        fonts:
          - asset: assets/fonts/wanted_sans_regular.ttf
            weight: 400
          - asset: assets/fonts/wanted_sans_semibold.ttf
            weight: 600
  ```
  > 폰트 파일은 APK 리소스에서 추출하거나 라이선스 확인 후 추가.
  > 추출 방법: `apktool d ~/dev/moabook/app/build/outputs/apk/debug/app-debug.apk -o /tmp/moabook_apk && find /tmp/moabook_apk/res/font/`

- [ ] **Step 3: assets 폴더 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/assets/fonts
  mkdir -p ~/dev/moabook-app/assets/images
  ```

- [ ] **Step 4: flutter pub get**
  ```bash
  cd ~/dev/moabook-app && flutter pub get
  ```

---

## Task 1: 디자인 토큰 (AppColors / AppTypography / AppSpacing)

**Files:**
- Create: `lib/app/theme/app_colors.dart`
- Create: `lib/app/theme/app_typography.dart`
- Create: `lib/app/theme/app_spacing.dart`
- Create: `lib/app/theme/app_theme.dart`
- Create: `test/app/theme/app_colors_test.dart`

- [ ] **Step 1: `lib/app/theme/app_colors.dart`**
  원본 `Color.kt` 를 1:1 이식:
  ```dart
  import 'package:flutter/material.dart';

  abstract final class AppColors {
    // Primary
    static const primary = Color(0xFF010196);

    // Text
    static const textPrimary   = Color(0xFF333333);
    static const textSecondary = Color(0xFFD4D4D4);
    static const textWhite     = Color(0xFFFFFFFF);
    static const textHint      = Color(0xFFD4D4D4);
    static const textGray      = Color(0xFF999999);

    // Background
    static const backgroundDefault = Color(0xFFEBEEF3);
    static const backgroundWhite   = Color(0xFFFFFFFF);
    static const backgroundGray    = Color(0xFFD4D4D4);
    static const backgroundDark    = Color(0xFF515151);
    static const inputBackground   = Color(0xFFF7F6EF);

    // Divider / Border
    static const dividerGray = Color(0xFFF5F5F5);
    static const borderBlack = Color(0xFF333333);

    // Surface
    static const surfaceGray = Color(0xFFEEEEEE);

    // Toast
    static const toastBackground = Color(0xFF515151);

    // Reading status
    static const statusWish    = Color(0xFFE8F0FF); // 읽고 싶은 책
    static const statusReading = Color(0xFFFFF3D6); // 읽는 중
    static const statusDone    = Color(0xFFD6FAE8); // 완독

    // Destructive
    static const dangerAccent = Color(0xFFE24646);
  }
  ```

- [ ] **Step 2: `lib/app/theme/app_spacing.dart`**
  ```dart
  import 'package:flutter/material.dart';

  abstract final class AppSpacing {
    static const double xs  =  4.0;
    static const double sm  =  8.0;
    static const double md  = 16.0;
    static const double lg  = 24.0;
    static const double xl  = 40.0;
    static const double xxl = 64.0;
  }
  ```

- [ ] **Step 3: `lib/app/theme/app_typography.dart`**
  폰트 파일 추가 후 작업. 폰트 없으면 시스템 폰트로 임시 대체:
  ```dart
  import 'package:flutter/material.dart';
  import 'app_colors.dart';

  abstract final class AppTypography {
    // DungGeunMo (픽셀/레트로)
    static const dungGeunMoHomeTitle = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 28, height: 48 / 28,
    );
    static const dungGeunMoHeader = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 22, height: 18 / 22,
    );
    static const dungGeunMoPopupTitle = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 18,
    );
    static const dungGeunMoBody = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 16, height: 1.0,
    );
    static const dungGeunMoSubtitle = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 14, height: 1.0,
    );
    static const dungGeunMoTag = TextStyle(
      fontFamily: 'DungGeunMo', fontSize: 12, height: 1.4,
    );

    // WantedSans (현대 산세리프)
    static const wantedSansBookTitle = TextStyle(
      fontFamily: 'WantedSans', fontWeight: FontWeight.w600,
      fontSize: 16, height: 18 / 16,
    );
    static const wantedSansBookTitleLarge = TextStyle(
      fontFamily: 'WantedSans', fontWeight: FontWeight.w600, fontSize: 20,
    );
    static const wantedSansBody = TextStyle(
      fontFamily: 'WantedSans', fontSize: 16, height: 22.4 / 16,
    );
    static const wantedSansBodySmall = TextStyle(
      fontFamily: 'WantedSans', fontSize: 14,
    );
    static const wantedSansCaption = TextStyle(
      fontFamily: 'WantedSans', fontSize: 10,
    );
  }
  ```

- [ ] **Step 4: `lib/app/theme/app_theme.dart`**
  ```dart
  import 'package:flutter/material.dart';
  import 'app_colors.dart';

  final appTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.backgroundDefault,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDefault,
    fontFamily: 'WantedSans',
    useMaterial3: true,
  );
  ```

- [ ] **Step 5: 컬러 토큰 단위 테스트**
  `test/app/theme/app_colors_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:moabook/app/theme/app_colors.dart';

  void main() {
    test('primary color is 0xFF010196', () {
      expect(AppColors.primary.value, 0xFF010196);
    });
    test('backgroundDefault is 0xFFEBEEF3', () {
      expect(AppColors.backgroundDefault.value, 0xFFEBEEF3);
    });
  }
  ```

- [ ] **Step 6: 테스트 실행**
  ```bash
  cd ~/dev/moabook-app && flutter test test/app/theme/
  ```

---

## Task 2: go_router 셋업

**Files:**
- Create: `lib/app/router/app_router.dart`
- Create: `lib/app/router/routes.dart`
- Create: `test/app/router/routes_test.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: `lib/app/router/routes.dart`** (경로 상수)
  Routes.kt 1:1 이식:
  ```dart
  abstract final class Routes {
    static const splash           = '/';
    static const login            = '/login';
    static const signup           = '/signup';
    static const main             = '/main';
    static const home             = '/main/home';
    static const searchBook       = '/main/search-book';
    static const addBook          = '/add-book';
    static const manualBookInput  = '/manual-book-input';
    static const barcode          = '/barcode';
    static const history          = '/main/history';
    static const setting          = '/main/setting';
    static const searchMyBook     = '/main/search-my-book';
    static const bookInfoBase     = '/main/book-info';
    static String bookInfo(int mybookId) => '$bookInfoBase/$mybookId';
  }
  ```

- [ ] **Step 2: `lib/app/router/app_router.dart`**
  ```dart
  import 'package:go_router/go_router.dart';
  import 'package:flutter/material.dart';
  import 'routes.dart';

  final appRouter = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Splash'))),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Login'))),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Signup'))),
      ),
      ShellRoute(
        builder: (_, __, child) => child, // Phase 3에서 BottomNavBar ShellRoute로 교체
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const Scaffold(body: Center(child: Text('Home'))),
          ),
          GoRoute(
            path: Routes.searchBook,
            builder: (_, __) => const Scaffold(body: Center(child: Text('SearchBook'))),
          ),
          GoRoute(
            path: Routes.history,
            builder: (_, __) => const Scaffold(body: Center(child: Text('History'))),
          ),
          GoRoute(
            path: Routes.setting,
            builder: (_, __) => const Scaffold(body: Center(child: Text('Setting'))),
          ),
          GoRoute(
            path: Routes.searchMyBook,
            builder: (_, __) => const Scaffold(body: Center(child: Text('SearchMyBook'))),
          ),
          GoRoute(
            path: '${Routes.bookInfoBase}/:mybookId',
            builder: (_, state) {
              final id = int.parse(state.pathParameters['mybookId']!);
              return Scaffold(body: Center(child: Text('BookInfo $id')));
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.addBook,
        builder: (_, __) => const Scaffold(body: Center(child: Text('AddBook'))),
      ),
      GoRoute(
        path: Routes.manualBookInput,
        builder: (_, __) => const Scaffold(body: Center(child: Text('ManualBookInput'))),
      ),
      GoRoute(
        path: Routes.barcode,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Barcode'))),
      ),
    ],
  );
  ```

- [ ] **Step 3: main.dart에서 go_router + Riverpod 연결**
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'app/router/app_router.dart';
  import 'app/theme/app_theme.dart';

  void main() {
    runApp(const ProviderScope(child: App()));
  }

  class App extends StatelessWidget {
    const App({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp.router(
        title: '모아북',
        theme: appTheme,
        routerConfig: appRouter,
      );
    }
  }
  ```

- [ ] **Step 4: 라우트 경로 단위 테스트**
  `test/app/router/routes_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:moabook/app/router/routes.dart';

  void main() {
    test('bookInfo path contains mybookId', () {
      expect(Routes.bookInfo(42), '/main/book-info/42');
    });
    test('splash is root path', () {
      expect(Routes.splash, '/');
    });
  }
  ```

- [ ] **Step 5: 테스트 실행**
  ```bash
  cd ~/dev/moabook-app && flutter test test/app/router/
  ```

---

## Task 3: Dio 클라이언트 + AuthInterceptor

**Files:**
- Create: `lib/core/network/dio_client.dart`
- Create: `lib/core/network/auth_interceptor.dart`
- Create: `lib/core/network/token_refresh_interceptor.dart`
- Create: `test/core/network/auth_interceptor_test.dart`

인터셉터 로직은 Android `AuthInterceptor.kt` + `TokenAuthenticator.kt` 기반.

- [ ] **Step 1: `lib/core/network/auth_interceptor.dart`**
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';

  class AuthInterceptor extends Interceptor {
    final FlutterSecureStorage _storage;

    AuthInterceptor(this._storage);

    @override
    Future<void> onRequest(
        RequestOptions options, RequestInterceptorHandler handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }
  }
  ```

- [ ] **Step 2: `lib/core/network/token_refresh_interceptor.dart`**
  Android `TokenAuthenticator` 포팅.
  401 수신 시 refresh token으로 재발급, 실패 시 강제 로그아웃 이벤트 발행.
  Phase 2 소셜 로그인 구현 후 실제 재발급 API 엔드포인트 연결:
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  class TokenRefreshInterceptor extends Interceptor {
    final Dio _dio;            // 재발급 전용 Dio (인터셉터 없는 별도 인스턴스)
    final FlutterSecureStorage _storage;

    TokenRefreshInterceptor(this._dio, this._storage);

    @override
    Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
      if (err.response?.statusCode != 401) {
        return handler.next(err);
      }

      final refreshToken = await _storage.read(key: 'refresh_token');
      final accessToken  = await _storage.read(key: 'access_token');
      if (refreshToken == null || accessToken == null) {
        await _clearTokens();
        return handler.next(err);
      }

      try {
        final response = await _dio.post(
          '/members/reissue',
          options: Options(headers: {
            'Authorization': 'Bearer $accessToken',
            'refresh-token': refreshToken,
          }),
        );

        final newAccess  = response.headers.value('Authorization');
        final newRefresh = response.headers.value('refresh-token');

        if (newAccess != null && newRefresh != null) {
          await _storage.write(key: 'access_token',  value: newAccess);
          await _storage.write(key: 'refresh_token', value: newRefresh);
          final retryOptions = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // 네트워크 일시 오류 → 토큰 유지, retry 포기
        if (e is DioException) {
          final code = e.response?.statusCode;
          if (code == 401 || code == 403 || code == 404) {
            await _clearTokens();
          }
        }
      }
      handler.next(err);
    }

    Future<void> _clearTokens() async {
      await _storage.deleteAll();
      // TODO Phase 2: AuthEvent 발행 (강제 로그아웃 → /login 리다이렉트)
    }
  }
  ```

- [ ] **Step 3: `lib/core/network/dio_client.dart`**
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:moabook/core/env/env.dart';
  import 'auth_interceptor.dart';
  import 'token_refresh_interceptor.dart';

  Dio createDioClient(FlutterSecureStorage storage) {
    final refreshDio = Dio(BaseOptions(baseUrl: Env.baseUrl));

    final dio = Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.addAll([
      AuthInterceptor(storage),
      TokenRefreshInterceptor(refreshDio, storage),
    ]);

    return dio;
  }
  ```

- [ ] **Step 4: AuthInterceptor 단위 테스트 (DoD 핵심)**
  `test/core/network/auth_interceptor_test.dart`:
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:moabook/core/network/auth_interceptor.dart';

  class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

  class FakeRequestInterceptorHandler extends Fake implements RequestInterceptorHandler {
    RequestOptions? captured;
    @override
    void next(RequestOptions options) { captured = options; }
  }

  void main() {
    late MockFlutterSecureStorage storage;
    late AuthInterceptor interceptor;

    setUp(() {
      storage = MockFlutterSecureStorage();
      interceptor = AuthInterceptor(storage);
    });

    test('adds Bearer token when access_token exists', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'test_token_123');

      final handler = FakeRequestInterceptorHandler();
      final options = RequestOptions(path: '/test');
      await interceptor.onRequest(options, handler);

      expect(handler.captured!.headers['Authorization'], 'Bearer test_token_123');
    });

    test('does not add header when no token', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => null);

      final handler = FakeRequestInterceptorHandler();
      final options = RequestOptions(path: '/test');
      await interceptor.onRequest(options, handler);

      expect(handler.captured!.headers.containsKey('Authorization'), isFalse);
    });
  }
  ```

  > mocktail 패키지 필요: `dev_dependencies`에 `mocktail: ^0.3.0` 추가.

- [ ] **Step 5: 테스트 실행**
  ```bash
  cd ~/dev/moabook-app && flutter test test/core/network/
  ```
  Expected: `All tests passed!`

---

## Task 4: PixelShadowBox — Flutter CustomPainter 이식

**Files:**
- Create: `lib/shared/widgets/pixel_shadow_box.dart`
- Create: `test/shared/widgets/pixel_shadow_box_test.dart`

원본 Compose 구현(`PixelShadowBox.kt`)의 시각 동작을 Flutter 위젯으로 1:1 재현.

- [ ] **Step 1: `lib/shared/widgets/pixel_shadow_box.dart`**
  ```dart
  import 'package:flutter/material.dart';
  import '../../app/theme/app_colors.dart';

  class PixelShadowBox extends StatelessWidget {
    final Widget child;
    final Color backgroundColor;
    final Color shadowColor;
    final double shadowOffset;
    final bool showBorder;
    final AlignmentGeometry contentAlignment;

    const PixelShadowBox({
      super.key,
      required this.child,
      this.backgroundColor = AppColors.backgroundGray,
      this.shadowColor = AppColors.borderBlack,
      this.shadowOffset = 1.0,
      this.showBorder = true,
      this.contentAlignment = Alignment.center,
    });

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(right: shadowOffset, bottom: shadowOffset),
        child: Stack(
          children: [
            // 그림자 레이어 (하위)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(shadowOffset, shadowOffset),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: shadowColor),
                ),
              ),
            ),
            // 콘텐츠 레이어 (상위)
            CustomPaint(
              painter: showBorder ? _PixelBorderPainter(pressed: false) : null,
              child: Container(
                color: backgroundColor,
                alignment: contentAlignment,
                child: child,
              ),
            ),
          ],
        ),
      );
    }
  }

  class PixelShadowButton extends StatefulWidget {
    final Widget child;
    final VoidCallback onTap;
    final Color backgroundColor;
    final Color shadowColor;
    final double shadowOffset;
    final bool isSelected;

    const PixelShadowButton({
      super.key,
      required this.child,
      required this.onTap,
      this.backgroundColor = AppColors.backgroundGray,
      this.shadowColor = AppColors.borderBlack,
      this.shadowOffset = 1.0,
      this.isSelected = false,
    });

    @override
    State<PixelShadowButton> createState() => _PixelShadowButtonState();
  }

  class _PixelShadowButtonState extends State<PixelShadowButton> {
    bool _pressed = false;

    bool get _showPressed => _pressed || widget.isSelected;

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          right: _showPressed ? 0 : widget.shadowOffset,
          bottom: _showPressed ? 0 : widget.shadowOffset,
        ),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Stack(
            children: [
              if (!_showPressed)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(widget.shadowOffset, widget.shadowOffset),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: widget.shadowColor),
                    ),
                  ),
                ),
              CustomPaint(
                painter: _PixelBorderPainter(pressed: _showPressed),
                child: Container(
                  color: widget.backgroundColor,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // 상/좌: white 1px, 우/하: black 1px (normal) / 반전 (pressed)
  class _PixelBorderPainter extends CustomPainter {
    final bool pressed;
    const _PixelBorderPainter({required this.pressed});

    @override
    void paint(Canvas canvas, Size size) {
      final topLeft  = pressed ? Colors.black : Colors.white;
      final botRight = pressed ? Colors.white : Colors.black;
      const s = 1.0;

      canvas.drawLine(Offset(0, s/2),      Offset(size.width, s/2),      Paint()..color = topLeft  ..strokeWidth = s);
      canvas.drawLine(Offset(s/2, 0),      Offset(s/2, size.height),     Paint()..color = topLeft  ..strokeWidth = s);
      canvas.drawLine(Offset(0, size.height - s/2), Offset(size.width, size.height - s/2), Paint()..color = botRight ..strokeWidth = s);
      canvas.drawLine(Offset(size.width - s/2, 0),  Offset(size.width - s/2, size.height), Paint()..color = botRight ..strokeWidth = s);
    }

    @override
    bool shouldRepaint(_PixelBorderPainter old) => old.pressed != pressed;
  }
  ```

- [ ] **Step 2: PixelShadowBox 스모크 테스트**
  `test/shared/widgets/pixel_shadow_box_test.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:moabook/shared/widgets/pixel_shadow_box.dart';

  void main() {
    testWidgets('PixelShadowBox renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PixelShadowBox(child: Text('test')),
        ),
      );
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('PixelShadowButton calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PixelShadowButton(
            onTap: () => tapped = true,
            child: const Text('btn'),
          ),
        ),
      );
      await tester.tap(find.text('btn'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  }
  ```

- [ ] **Step 3: 테스트 실행**
  ```bash
  cd ~/dev/moabook-app && flutter test test/shared/widgets/
  ```

---

## Task 5: flutter_svg 셋업 + SVG 에셋 확인

**Files:**
- Create: `assets/images/` (SVG 파일 위치)
- Create: `lib/shared/widgets/svg_icon.dart`

- [ ] **Step 1: SVG 소스 파일 목록 확인**
  원본 Android drawable을 SVG로 변환 또는 Figma에서 export:
  ```bash
  find ~/dev/moabook -name "*.svg" -o -name "*.xml" | grep -v build | grep drawable | head -20
  ```
  > Phase 3 화면 구현 전까지 SVG 파일은 placeholder로 두어도 됨.

- [ ] **Step 2: `lib/shared/widgets/svg_icon.dart`** (편의 래퍼)
  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_svg/flutter_svg.dart';

  class SvgIcon extends StatelessWidget {
    final String assetPath;
    final double? size;
    final Color? color;

    const SvgIcon(this.assetPath, {super.key, this.size, this.color});

    @override
    Widget build(BuildContext context) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: color != null
            ? ColorFilter.mode(color!, BlendMode.srcIn)
            : null,
      );
    }
  }
  ```

---

## Task 6: 전체 테스트 + flutter analyze + 커밋

- [ ] **Step 1: 전체 테스트**
  ```bash
  cd ~/dev/moabook-app && flutter test
  ```
  Expected: 모든 테스트 통과 (auth_interceptor_test 포함)

- [ ] **Step 2: flutter analyze**
  ```bash
  flutter analyze --fatal-infos
  ```
  Expected: 0 issues

- [ ] **Step 3: 커밋 + push**
  ```bash
  cd ~/dev/moabook-app
  git add .
  git status  # 민감 파일 staged 안 됨 확인
  git commit -m "feat: Phase 1 — theme tokens, go_router, Dio+interceptors, PixelShadowBox, Riverpod"
  git push origin main
  ```

---

## Phase 1 Definition of Done

- [ ] `flutter test` → 전 항목 pass (auth_interceptor_test 포함)
- [ ] `flutter analyze --fatal-infos` → 0 issues
- [ ] 시뮬레이터에서 앱 실행 시 go_router splash 경로 표시
- [ ] `AppColors.primary` == `0xFF010196` 단위 테스트 pass
- [ ] `Routes.bookInfo(42)` == `"/main/book-info/42"` 단위 테스트 pass
- [ ] `AuthInterceptor` Bearer 헤더 주입 테스트 pass
- [ ] `PixelShadowBox` / `PixelShadowButton` 위젯 테스트 pass

---

## 다음 단계

Phase 1 DoD 체크 완료 후 → `docs/superpowers/plans/2026-05-25-phase-2-auth.md` 작성.
Phase 2 범위: 카카오/네이버/구글 소셜 로그인, AuthRepository, AccessToken/RefreshToken SecureStorage 저장.
