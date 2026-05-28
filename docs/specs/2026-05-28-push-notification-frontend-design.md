# 푸시 알림 프론트 설계 (moabook-app)

- 작성일: 2026-05-28
- 대상 저장소: `moabook-app` (Flutter + Riverpod)
- 관련 백엔드 문서: `damda-server/docs/specs/2026-05-28-push-notification-backend-design.md`

## 1. 목적

모아북 앱 푸시 알림(A/B/C) 클라이언트 구현. FCM 메시지 수신/표시/딥링크 라우팅, 로컬 알림 기반 C 트리거, 알림 설정 UI 및 디바이스 토큰 등록 관리.

## 2. 알림 종류 (프론트 책임 범위)

| 종류 | 처리 위치 | 비고 |
| --- | --- | --- |
| A. 저장 유도 | FCM 수신 → 시스템 알림 표시 → 탭 시 바코드 스캔 화면 | 백엔드 트리거 |
| B. 저장한 책 리마인드 | FCM 수신 → 시스템 알림 표시 → 탭 시 책 상세 화면 | 백엔드 트리거 |
| C. 재방문 유도 | **로컬 알림** (서버 무관) — 앱 진입 시 7일 뒤 재예약 | 클라 자체 트리거 |

## 3. 패키지 추가

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^17.2.3
  permission_handler: ^11.3.1  # iOS 알림 권한
  shared_preferences: ^2.3.2   # 푸시 토글 캐시
```

Android Gradle 변경:
- `android/build.gradle.kts` Google services plugin 추가
- `android/app/build.gradle.kts` `com.google.gms.google-services` 적용
- `google-services.json` → `android/app/`

iOS 변경:
- `GoogleService-Info.plist` → `ios/Runner/`
- `ios/Runner/AppDelegate.swift` Firebase 초기화 + APNs 토큰 위임
- `ios/Runner/Info.plist` `UIBackgroundModes` `remote-notification` 추가
- Apple Developer Console에서 APNs 인증 키 발급 후 Firebase Console 업로드

## 4. 아키텍처

```
lib/features/notification/
├── provider/
│   ├── fcm_provider.dart            // FCM 초기화 + 토큰 수신 stream
│   ├── push_settings_provider.dart  // ON/OFF 상태
│   └── local_notification_provider.dart  // C 알림 예약/취소
├── service/
│   ├── fcm_service.dart             // initialize, onMessage, onMessageOpenedApp
│   ├── local_notification_service.dart  // flutter_local_notifications 래퍼
│   └── push_routing_service.dart    // payload → route 매핑
└── screen/
    └── notification_settings_screen.dart  // 토글 UI (또는 settings_screen 확장)

lib/data/
├── datasource/
│   └── notification_remote_datasource.dart  // /notifications/* API
├── model/
│   └── push_settings_model.dart
└── repository/
    └── notification_repository_impl.dart

lib/domain/
├── model/
│   └── push_settings.dart
└── repository/
    └── notification_repository.dart
```

## 5. FCM 초기화 흐름

### 5.1 앱 시작 시 (`main.dart`)

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 5.2 로그인 성공 후

1. `FirebaseMessaging.instance.requestPermission()` (iOS 권한 다이얼로그)
2. `FirebaseMessaging.instance.getToken()` 으로 FCM 토큰 획득
3. `POST /notifications/device-token` 으로 서버 등록
4. `FirebaseMessaging.instance.onTokenRefresh` 구독 → 갱신 시 재등록

### 5.3 로그아웃 시

1. `DELETE /notifications/device-token` 호출
2. `FirebaseMessaging.instance.deleteToken()`
3. 로컬 알림 모두 취소

## 6. 메시지 수신 처리

### 6.1 포그라운드 (`onMessage`)

```dart
FirebaseMessaging.onMessage.listen((message) {
  // 시스템 트레이에 표시되지 않음 → flutter_local_notifications 로 직접 표시
  _localNotificationService.show(message.notification, message.data);

  // A 푸시 도착 시 C 로컬 알림은 어차피 앱이 열렸을 때 재예약되므로 추가 처리 불필요
});
```

### 6.2 백그라운드 / 종료 상태 (`onMessageOpenedApp` / `getInitialMessage`)

```dart
// 알림 탭으로 앱 진입
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) _routePushTap(initial);

FirebaseMessaging.onMessageOpenedApp.listen(_routePushTap);
```

### 6.3 라우팅 매핑

| `data.type` | 추가 필드 | 라우트 |
| --- | --- | --- |
| `"A"` | — | `/barcode` |
| `"B"` | `mybookId` | `/mybook/{mybookId}` |
| (없음, 로컬) | — | `/home` |

`go_router` 의 `GoRouter.of(context).go(...)` 또는 글로벌 navigator 사용.

## 7. C 알림 — 로컬 알림 (서버 무관)

### 7.1 트리거 정의

**앱 진입(foreground 진입)을 안 한 지 7일이 지나면 발동.**

### 7.2 동작

`WidgetsBindingObserver` 의 `didChangeAppLifecycleState`:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    ref.read(localNotificationServiceProvider).rescheduleC();
  }
}
```

`rescheduleC()`:
1. 기존 예약된 C 알림 모두 취소 (`cancel(C_NOTIFICATION_ID)`)
2. 7일 뒤 시각으로 새로 예약 (`zonedSchedule`)

### 7.3 문구 (랜덤 선택, 클라 측에서 결정)

- "요즘 읽고 싶은 책은 없으세요? 새로운 책을 담아보세요"
- "오랜만에 내 서점 구경 어때요"
- "내 서점에 먼지가 쌓이고 있어요…"

### 7.4 탭 시 동작

`flutter_local_notifications` 의 `onDidReceiveNotificationResponse` 콜백에서 `/home` 으로 라우팅.

### 7.5 권한

- iOS: 푸시 권한과 동일하게 `requestPermission()` 후 사용
- Android 13+: `permission_handler` 로 `Permission.notification` 요청

### 7.6 로그아웃/푸시 OFF 시

- 모든 C 예약 취소
- `push_enabled = false` 시에도 C 미예약 (일관성)

## 8. 알림 설정 UI

`lib/features/settings/screen/settings_screen.dart` 기존 화면에 항목 추가.

### 8.1 화면

```
┌──────────────────────────────┐
│ 알림                         │
│                              │
│ ┌──────────────────────────┐ │
│ │ 푸시 알림 받기  [●ON]    │ │
│ └──────────────────────────┘ │
│                              │
│ 책을 잊지 않도록 모아북이    │
│ 가끔 알려드려요.             │
└──────────────────────────────┘
```

### 8.2 동작

- 초기 진입 시 `GET /notifications/settings` 호출 → 토글 반영
- 토글 변경 → `PATCH /notifications/settings { pushEnabled: ... }`
- OFF 전환:
  - `FirebaseMessaging.instance.deleteToken()`
  - `DELETE /notifications/device-token`
  - 모든 로컬 알림 취소
- ON 전환:
  - 시스템 푸시 권한 확인. 없으면 권한 요청
  - 권한 있으면 FCM 토큰 재발급 → 서버 등록
  - C 로컬 알림 예약

### 8.3 시스템 권한 OFF 시

- 토글은 ON이지만 OS 차원에서 푸시 거부된 상태 안내
- "설정 앱에서 알림을 켜주세요" 링크 (deep link to system settings)

## 9. API 클라이언트

`lib/core/network/dio_client.dart` 기존 dio 사용. 인증 인터셉터 자동 적용.

```dart
// notification_remote_datasource.dart
Future<void> registerDeviceToken(String fcmToken, String platform);
Future<void> unregisterDeviceToken(String fcmToken);
Future<PushSettingsModel> getSettings();
Future<PushSettingsModel> updateSettings(bool enabled);
```

## 10. 상태 관리 (Riverpod)

```dart
@riverpod
class PushSettings extends _$PushSettings {
  @override
  Future<PushSettingsState> build() async {
    return ref.read(notificationRepositoryProvider).getSettings();
  }

  Future<void> toggle(bool enabled) async {
    state = const AsyncValue.loading();
    await ref.read(notificationRepositoryProvider).updateSettings(enabled);
    if (enabled) {
      await ref.read(fcmServiceProvider).enable();
    } else {
      await ref.read(fcmServiceProvider).disable();
    }
    state = AsyncValue.data(PushSettingsState(enabled: enabled));
  }
}
```

## 11. 구현 단계

| 단계 | 범위 | 산출물 |
| --- | --- | --- |
| **P0** | Firebase 프로젝트 생성 + iOS/Android SDK 셋업 + FCM 토큰 획득/서버 등록 + 알림 권한 다이얼로그 | 인프라 검증 |
| **P1** | 포그라운드/백그라운드 메시지 수신 + 시스템 알림 표시 + 페이로드 기반 deep link 라우팅 (`/barcode`, `/mybook/{id}`) | A/B 푸시 수신 가능 |
| **P2** | 설정 화면 토글 + `GET/PATCH /notifications/settings` 연동 + 로그아웃 시 토큰 해제 | 유저 제어 가능 |
| **P3** | C 로컬 알림 예약/취소 + 라이프사이클 훅 + 권한 안내 | C 트리거 완성 |
| **P4** | 무효 토큰 자동 갱신 (`onTokenRefresh`) + 시스템 권한 동기화 + 에러 핸들링 | 운영 안정성 |

## 12. 위험과 대응

| 위험 | 대응 |
| --- | --- |
| iOS 알림 권한 거부 | 설정 화면에서 "OS 설정에서 켜주세요" 안내. `app_settings` 패키지로 시스템 설정 이동 |
| Android 13+ `POST_NOTIFICATIONS` 권한 거부 | 동일하게 안내. 최초 로그인 후 권한 요청 |
| 백그라운드 핸들러 자동 실행 안 됨 (`isolate` 분리) | top-level 함수로 선언, `@pragma('vm:entry-point')` 마킹 |
| 로컬 알림 권한과 푸시 권한 분리됨 (iOS) | 둘 다 `firebase_messaging.requestPermission()`으로 일괄 요청 |
| 앱 완전 삭제 시 C 예약 사라짐 | 의도된 동작 (재설치 = 새 시작) |
| 시뮬레이터에서 FCM 토큰 미발급 | 실기기 테스트 필수 명시 |
| `home_widget` 와 알림 충돌 | 별도 채널/ID 사용, 영향 없음 |

## 13. 미정 / 후속

- Firebase 프로젝트 신규 생성 vs 기존 (`moabook` 또는 신규?) — 운영자 결정 필요
- iOS APNs 인증 키 발급 (Apple Developer Console)
- 알림 채널 분류 (Android) — A/B/C 각각 별도 채널 vs 단일 채널
- 푸시 도착 통계 (오픈율) — 추후 Firebase Analytics 연계
- 깊은 링크 vs in-app 네비게이션 일관성 (현재 go_router 라우트 사용)
