# 모아북 Flutter 재구축 — Phase 로드맵 (Meta Plan)

> **For agentic workers:** This is a **roadmap document**, not a directly executable plan. Each Phase below will have its own detailed task-by-task plan file generated in this same directory before execution.
>
> **Source spec:** [`docs/superpowers/specs/2026-05-25-flutter-rebuild-design.md`](../specs/2026-05-25-flutter-rebuild-design.md)

**Goal:** 기존 Android(`project.side.ikdaman`, v1.0.22)와 iOS(`com.gogochang.Ikdaman`, v1.0) 앱을 단일 Flutter 코드베이스(`~/dev/moabook-app`)로 통합 재구축. 양 OS 스토어 연속성(패키지/번들/서명/버전 단조성)을 유지한 채 v2.0.0으로 빅뱅 출시.

**Architecture:** Clean Architecture (presentation/domain/data 3 layer) + Riverpod 2.x (code-generation). Android Glance 위젯은 이식해서 유지하고 Flutter는 `home_widget`으로 데이터 supplier 역할. iOS WidgetKit은 신규(App Group `group.shop.moabook`).

**Tech Stack:** Flutter (Dart 3.x), Riverpod 2.x, go_router, Dio + retrofit-dart + json_serializable, flutter_secure_storage + shared_preferences, kakao_flutter_sdk_user, google_sign_in, flutter_naver_login, mobile_scanner, home_widget, cached_network_image, flutter_native_splash.

---

## Phase 의존 그래프

```
Phase 0 (셋업 + Identity)
        │
        ▼
Phase 1 (핵심 인프라)
        │
        ▼
Phase 2 (인증 + 도메인/data layer)
        │
        ▼
Phase 3 (핵심 화면)
        │
        ├──────────────┐
        ▼              ▼
Phase 4 (바코드)   Phase 5 (위젯 통합)   ← 병렬 가능
        │              │
        └──────┬───────┘
               ▼
        Phase 6 (출시 준비)
```

병렬 가능한 구간은 Phase 4 ↔ Phase 5 한 쌍.

---

## Phase 0 — 프로젝트 셋업 + Identity 잠금

**목적:** 빈 Flutter 앱을 만들고 양 OS의 패키지명/번들 ID/서명/버전을 기존 스토어 식별자에 정확히 맞춤. 이후 모든 phase는 이 토대 위에 쌓임.

**산출물 (Definition of Done):**
- **[선행 작업 — Phase 0 시작 전]** `~/dev/moabook/screenshots/baseline/` 에 Compose 베이스라인 스크린샷 15개 × 2상태(filled/empty) 캡쳐 완료 (§6.3 절차 참고). 테스트 계정 로그인 + 책 7~10권 등록 후 시스템 UI 숨김 상태로 캡쳐.
- `~/dev/moabook-app` 디렉터리에 Flutter 프로젝트 존재 (`flutter doctor` 통과)
- Android `applicationId == project.side.ikdaman`, `namespace` 일치, `versionCode == 23`, `versionName == 2.0.0`
- iOS `PRODUCT_BUNDLE_IDENTIFIER == com.gogochang.Ikdaman`, `CFBundleShortVersionString == 2.0.0`, `CFBundleVersion == 기존+1`
- 앱 표시명 "모아북" (양 OS)
- 기존 `release.keystore` + `key.properties` 이식 후 `flutter build appbundle --release` 성공
- `apksigner verify --print-certs` 결과 SHA가 기존 v1.0.22 빌드의 SHA와 **동일** (CI에서 자동 비교)
- `--dart-define-from-file=env/prod.json` env 시스템 동작 (`env/` gitignore)
- GitHub Actions에 Identity Gate 워크플로 추가 (4가지 grep/SHA 체크)

**핵심 작업 영역:**
- Flutter 신규 프로젝트 생성 (`flutter create --org project.side --project-name moabook ~/dev/moabook-app`)
- Android: `android/app/build.gradle.kts`, `android/app/src/main/res/values/strings.xml`, 키스토어 파일들
- iOS: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, Xcode signing
- env 시스템: `env/prod.json` 스키마, `lib/core/env/env.dart` 빌드타임 주입 래퍼
- CI: `.github/workflows/identity-gate.yml` 신규
- 기존 `~/dev/moabook` 의 `release.keystore`, `key.properties` 복사 + gitignore 확인

**의존성:** 없음 (출발점)

**위험 요소:**
- iOS `CFBundleVersion` 의 기존 마지막 빌드 번호를 App Store Connect에서 확인 필요 (1인 작업이면 잊기 쉬움 → Phase 0 plan의 첫 단계로 박음)
- 키스토어 비밀번호가 1Password 등에 있는지 확인 — 잃으면 복구 불가

**예상 plan 분량:** 중 (15~25 tasks). 대부분 셋업 명령 + 검증.

---

## Phase 1 — 핵심 인프라

**목적:** 화면을 구현하기 전에 모든 화면이 공유할 기반(테마, 라우터, 네트워크, 상태관리, 저장소, 에러 처리)을 깐다. 인터셉터의 401→refresh, 5xx→unauthorized 로직은 현 Android의 동작과 동일하게.

**산출물:**
- `lib/app/theme/` 에 Color/Type/Spacing/Theme 토큰 (현 `ui/theme/` 1:1 포팅) + Material 3 ThemeData
- `lib/app/router.dart` 에 go_router 정의 (현 `Routes.kt` 1:1 매핑)
- `lib/core/network/dio_client.dart` + `lib/core/network/interceptors/` (AuthInterceptor, FiveXxAsUnauthorizedInterceptor 등) — 현 Android 인터셉터 테스트 패리티
- `lib/core/storage/secure_storage.dart`, `lib/core/storage/prefs.dart` 래퍼
- `lib/core/error/failure.dart`, `app_exception.dart`
- `lib/main.dart` + `lib/app/app.dart` Riverpod ProviderScope 부트, splash 화면 1개 (placeholder)
- 단위 테스트: 인터셉터 401 refresh / 5xx-unauthorized / 일반 흐름 3종 (현 Android 테스트 명세 그대로)
- `flutter_lints` + `custom_lint` + `import_lint` 셋업 (feature 간 import 금지 규칙 1개라도)

**핵심 작업 영역:**
- 현 Android `remote/RemoteModule.kt`, `AuthInterceptor.kt`, `FiveXxAsUnauthorizedInterceptor.kt`, `TokenCacheManager.kt` 코드를 Dart로 포팅
- 현 `ui/theme/Color.kt`, `Type.kt`(13개 TextStyle 1:1), `Spacing.kt`, `Theme.kt` 를 Dart로 포팅. 폰트 DungGeunMo + WantedSans pubspec 등록
- **`PixelShadowBox` / `PixelShadowButton` CustomPainter 구현** — 픽셀 단위 보더 + pressed 상태 포함. 골든 테스트 3개
- **`flutter_svg` 셋업** + drawable XML → SVG 변환 일괄 처리 (`assets/icons/`)
- 현 `app/MainActivity.kt`의 `Routes.kt`, `WidgetIntentParser.kt` 매핑 (다만 navigation 자체는 stub만)
- Riverpod `riverpod_generator` 코드 생성 빌드 셋업

**의존성:** Phase 0 완료

**위험 요소:**
- 인터셉터의 토큰 refresh 로직은 동시성 (여러 요청이 동시에 401 받을 때 단일 refresh 호출 보장) 처리가 까다로움 — 현 Android 코드의 동시성 처리 방식을 그대로 답습할지 결정 필요
- Riverpod codegen + retrofit-dart codegen + json_serializable codegen 빌드 순서 충돌 가능성 (`build_runner watch` 1회 셋업 필요)

**예상 plan 분량:** 중 (20~30 tasks).

---

## Phase 2 — 인증 + 도메인/data layer

**목적:** 소셜 로그인 3종(Kakao/Google/Naver)로 토큰을 발급받아 백엔드의 `/members/me` 가 200을 반환할 때까지의 end-to-end 경로 완성. 토큰은 `flutter_secure_storage`(Keychain/EncryptedSharedPreferences)에.

**산출물:**
- `lib/domain/entity/` Member, AuthEvent, SocialLoginResult, LoginResult 등 (현 Android entity 1:1)
- `lib/domain/repository/` AuthRepository, MemberRepository, AuthEventRepository 인터페이스
- `lib/data/repository/` 구현체 3종
- `lib/data/datasource/local/auth_local_data_source.dart` (secure storage 사용, 현 `AuthDataStoreSourceImpl` 매핑 — 단 키 이름 새로 잡음, orphan 인계 없음)
- `lib/data/datasource/social/kakao_login_source.dart`, `google_login_source.dart`, `naver_login_source.dart`
- `lib/data/datasource/remote/member_api.dart` (retrofit-dart로 `/members/me` 등)
- 카카오 OAuth deep link 핸들러 (Android manifest + `app_links` 수신)
- 단위 테스트: 각 repository happy + 1 error 경로
- 임시 로그인 화면 1개로 전체 흐름 수동 검증

**핵심 작업 영역:**
- 현 `domain/`, `data/repository/`, `data/datasource/AuthDataSource.kt`, `SocialAuthDataSource.kt`, `MemberDataSource.kt`, `data/auth/TokenCacheManager.kt`, `remote/` API 인터페이스를 Dart로 포팅
- Android `AndroidManifest.xml` 의 Kakao OAuth deep link 그대로 신규 프로젝트에 이식
- iOS `Info.plist` 의 Kakao URL Scheme 신규 추가 (현 iOS 앱에 있었으면 같은 값으로, 없었으면 신규)

**의존성:** Phase 1 완료 (인터셉터·secure storage·라우터 필요)

**위험 요소:**
- `flutter_naver_login` 패키지가 최신 네이버 SDK와 호환 안 되면 method channel로 직접 구현 필요 (fallback plan은 spec §4A에 명시). Phase 2 plan 첫 단계에서 호환성 검증을 task로 박음
- Kakao SDK는 카카오 공식이라 안정적, Google은 공식이라 안정적

**예상 plan 분량:** 중-대 (30~45 tasks). 소셜 로그인 3종 + repository 3개 + 토큰 인터셉터 통합.

---

## Phase 3 — 핵심 화면

**목적:** 위젯/스캐너를 제외한 사용자가 직접 조작하는 모든 화면 구현. 양 OS에서 손으로 만져볼 수 있는 앱 완성.

**산출물 (화면 단위):**
- `lib/features/splash/` — SplashScreen
- `lib/features/auth/login/`, `auth/signup/` (LoginScreen, SignupScreen, SignupDataHolder 매핑)
- `lib/features/home/` — HomeScreen (현 Android의 책 그리드 + 캐릭터 + 말풍선)
- `lib/features/book_search/` — SearchBookScreen, AddBookScreen, ManualBookInputScreen
- `lib/features/book_info/` — BookInfoScreen
- `lib/features/my_book_search/` — MyBookSearchScreen
- `lib/features/history/` — HistoryScreen
- `lib/features/settings/` — SettingScreen, NicknameChangeScreen
- `lib/shared/component/` — BottomNavBar, TitleBar, CustomSnackBar, PixelShadowBox, ReadingStartBottomSheet, BookRegisterBottomSheet, BookEditBottomSheet, CalendarBottomSheet, CalendarPicker, HomeBookItem, RetroLoading
- 각 화면의 Riverpod Notifier + AsyncValue 상태
- 화면별 `matchesGoldenFile` 골든 테스트 (filled/empty 2상태) + Compose 베이스라인과 사람 눈 비교 첨부
- **스플래시 → 홈 전환 페이드 + 캐릭터 슬라이드 인 모션** (1.5초 이내)
- **책 등록 성공 micro-interaction** (캐릭터 반응 + 펄스/confetti, 1초 이내)
- 양 OS 실기 빌드 + 수동 클릭 시나리오 통과 (로그인 → 홈 → 책 검색 → 등록 → 책 정보 → 히스토리 → 설정)

**핵심 작업 영역:**
- 현 `ui/screen/`, `ui/component/`, `ui/sheet/`, `ui/snackbar/` 등 모든 Compose 코드를 Flutter 위젯으로 포팅
- 현 `presentation/viewmodel/` 의 각 ViewModel을 Riverpod Notifier로 포팅
- 사용자 데이터 마이그레이션 첫 실행 안내 다이얼로그 (spec §2)

**의존성:** Phase 2 완료 (인증/repository 필요)

**위험 요소:**
- 화면 양이 많아 가장 일정 슬립 가능성 높은 phase. Plan 분할 시 화면 그룹(auth / home / book / settings) 단위로 sub-plan 4개로 또 쪼개는 것을 권장
- Compose의 미세한 UI 동작(예: 키보드 IME 대응, 시스템 바, 다크모드)을 Flutter로 옮길 때 1:1 동일하지 않은 경우 발생 → 디자인 디테일은 양 OS 디자인 토큰에 통일

**예상 plan 분량:** 대 (50~80 tasks, 화면 그룹별 sub-plan으로 쪼개면 각 15~25).

---

## Phase 4 — 바코드 스캐너

**목적:** ISBN 바코드 스캔 → 알라딘 검색 결과로 점프. 책 등록 흐름 안에서 핵심.

**산출물:**
- `lib/features/barcode/` — BarcodeScannerScreen (`mobile_scanner` 사용)
- 카메라 권한 핸들링 (Android `CAMERA`, iOS `NSCameraUsageDescription`)
- 스캔 결과 → `book_search` feature로 ISBN 전달 (라우터)
- 실기 검증: 실제 책 ISBN 1권 스캔 → 알라딘 결과 수신

**핵심 작업 영역:**
- 현 `ui/screen/BarcodeScreen.kt`, `BarcodeScanner.kt` 로직을 `mobile_scanner` API로 재구현
- `ios/Runner/Info.plist` 에 `NSCameraUsageDescription` 한국어 카피 추가

**의존성:** Phase 3 완료 (book_search 화면이 있어야 결과 전달 가능)

**위험 요소:**
- `mobile_scanner`의 iOS 카메라 권한 흐름이 처음 거부되면 다시 묻기 어려움 → 권한 요청 UI 분기 필요
- 가능한 병렬: Phase 5와 동시 진행 가능 (서로 영향 zero)

**예상 plan 분량:** 소 (8~15 tasks).

---

## Phase 5 — 위젯 통합

**목적:** Android Glance 위젯을 이식하고 iOS WidgetKit을 신규 구축. Flutter는 `home_widget`으로 데이터만 공급. 기존 Android 위젯 사용자에게 cold-start 동작 보장.

**산출물:**

### 5-A. Android Glance 이식
- 기존 `widget/` Gradle 모듈의 Kotlin 코드 전체를 `android/app/src/main/kotlin/project/side/ikdaman/glance/` 로 이식
- `WidgetCache`의 read 경로를 `DataStore("widget_cache")` → `SharedPreferences("HomeWidgetPreferences")` 로 변경 (Glance 디코딩 코드 무수정, key/JSON 포맷 동일)
- `widget_prefs`(색상)는 그대로 유지
- `WidgetIntentParser.kt` 그대로 유지, `MainActivity`가 `FlutterActivity`인 환경에서 동작 검증

### 5-B. iOS WidgetKit 신규
- Xcode에 Widget Extension target 추가 (SwiftUI)
- Apple Developer Portal에 `group.shop.moabook` App Group 등록 + Provisioning Profile 재발급
- WidgetKit View 3개 (S/M/L) — Android Glance 디자인을 SwiftUI로 재현
- `UserDefaults(suiteName: "group.shop.moabook")` 에서 동일 JSON 디코딩
- `WidgetCenter.shared.reloadAllTimelines()` 호출 진입점

### 5-C. Flutter 브리지
- `lib/widget_bridge/widget_publisher.dart` — `HomeWidget.saveWidgetData()` + `HomeWidget.updateWidget()` 래퍼
- `lib/widget_bridge/widget_book.dart` — `WidgetBook` 모델 (snake_case JSON, kotlinx.serialization과 1:1)
- Phase 3 의 홈 화면 데이터가 갱신될 때마다 widget_publisher 호출
- Cold-start: 첫 부팅 + 로그인 성공 직후 1회 강제 publish

### 5-D. 검증
- 골든 픽스처 JSON 1개로 Glance + WidgetKit 양쪽 디코딩 성공 CI 테스트
- 수동: 기존 v1.0.22 Android 디바이스에 위젯 배치 → v2.0.0 업데이트 → cold-start로 위젯 채워지는지 확인

**의존성:** Phase 3 완료 (위젯이 publish할 책 데이터 layer 필요)

**위험 요소:**
- iOS Widget Extension은 메인 앱과 별도 프로세스 + 별도 entitlements 파일이라 셋업 까다로움. Apple Developer Portal 작업이 외부 의존성
- App Group 등록 후 Provisioning Profile 재발급이 30분~수시간 걸릴 수 있음 → Phase 5 plan 시작 즉시 등록 task를 박음
- Glance 코드의 Hilt DI 의존성 분리: 현재 `WidgetModule.kt`가 Hilt에 묶여있는데 Flutter 환경에선 Hilt를 안 쓸 수도 있음. 위젯 코드만 별도 Hilt scope로 살릴지 결정 필요

**예상 plan 분량:** 대 (40~60 tasks, A/B/C/D 4 sub-plan으로 또 쪼개도 좋음).

---

## Phase 6 — 출시 준비

**목적:** spec §5.3 수동 verify 5종 통과 + 스토어 업로드 준비.

**산출물:**
- 출시 체크리스트(spec §5.4)의 모든 항목 통과
- 스토어 What's New 텍스트 (양 OS, 한국어)
- 첫 실행 재로그인 다이얼로그 카피 최종 확정
- Play Console 내부 테스트 트랙에 AAB 업로드
- TestFlight 내부 테스터 그룹에 IPA 업로드
- 양 OS 디바이스에서 spec §5.3 시나리오 1~5 통과 기록

**핵심 작업 영역:**
- 스토어 카피 작성 (마케팅 결정)
- Identity Gate CI (Phase 0에서 만든) 가 마지막 빌드에 대해 green
- **CI 자동 배포 워크플로**: `main` push → Identity Gate → 테스트 → 빌드/서명 → Play Console Internal + TestFlight 자동 업로드. 기존 `deploy-android.yml` / `deploy-ios.yml` Flutter용으로 재작성
- staged rollout 셋업: Play Console 1%→10%→50%→100% 단계, App Store는 phased release ON

**의존성:** Phase 5 (모든 기능 완성), Phase 4

**위험 요소:**
- TestFlight 첫 빌드 처리에 24시간 소요 가능 → 일정 여유 필요
- 스토어 심사 reject 가능성(특히 iOS): 기존 앱과 패키지/번들 ID 동일하다고 해도 카메라 권한 설명 부족 등으로 reject 받을 수 있음

**예상 plan 분량:** 소 (10~15 tasks).

---

## 마일스톤 요약

| Phase | 누적 시점 | 사용자가 손으로 만질 수 있는 것 |
|---|---|---|
| 0 | 빈 앱 빌드/서명 검증 | 빈 화면 1개 |
| 1 | 인프라 완성 | 토큰 인터셉터 단위 테스트 pass |
| 2 | 인증 동작 | 로그인해서 `/members/me` 200 받기 |
| 3 | 핵심 화면 완성 | 위젯/스캐너 빼고 손으로 다 만짐 |
| 4 | 스캐너 동작 | 책 ISBN 스캔 → 검색 결과 |
| 5 | 위젯 동작 | 양 OS 위젯 정상 표시 |
| 6 | 출시 준비 끝 | Play/TestFlight 내부 트랙에 배포 |

---

## 진행 절차

1. **Phase 0 detailed plan**을 별도 파일(`docs/superpowers/plans/2026-05-25-phase-0-setup.md`)에 작성 → 합의 → 실행
2. Phase 0 완료 후 회고 → Phase 1 detailed plan 작성
3. … (각 phase 동일 패턴)
4. Phase 3, 5 는 sub-plan으로 분할 권장 (큰 phase는 sub-plan 단위로 또 쪼갬)
5. Phase 4와 5는 병렬 실행 가능 (별도 worktree 권장)

---

## 변경 이력

- 2026-05-25 v0.1 — 초안 (phase 7개, 의존 그래프, 마일스톤 정의)
- 2026-05-25 v0.2 — 인터뷰 7라운드 반영: 베이스라인 캡쳐(Phase 0 선행), PixelShadowBox+flutter_svg(Phase 1), 골든테스트+모션(Phase 3), CI 자동배포(Phase 6)
