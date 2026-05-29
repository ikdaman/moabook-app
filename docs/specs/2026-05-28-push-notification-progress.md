# 푸시 알림 프론트 진행 체크리스트

- 시작일: 2026-05-28
- 설계 문서: `2026-05-28-push-notification-frontend-design.md`
- 백엔드 설계: `damda-server/docs/specs/2026-05-28-push-notification-backend-design.md`

체크박스 표기:
- `[x]` 완료
- `[ ]` 미착수
- `[~]` 진행 중
- `[!]` 차단됨 (의존성 대기)

---

## 인프라 셋업 (1회성)

- [x] Firebase 프로젝트 생성 (`moabook-b1d0a`)
- [x] iOS 앱 등록 + `GoogleService-Info.plist` 다운로드
- [x] Android 앱 등록 + `google-services.json` 다운로드
- [x] APNs 인증키(.p8) 발급 (`AuthKey_P7533549BD.p8`, Key ID `P7533549BD`, Team ID `T583WJWNAK`)
- [x] Firebase Console → Cloud Messaging → APNs Authentication Key 업로드
- [x] iOS plist 병합 (Firebase + Google Sign-In CLIENT_ID/REVERSED_CLIENT_ID) → `ios/Runner/GoogleService-Info.plist`
- [x] `secrets/` 디렉토리 + `.gitignore` 등록 (`secrets/`, `*.p8`, `**/google-services.json` 등)
- [x] `google-services.json` 을 `android/app/` 로 이동 (Gradle 자동 인식 위치)
- [ ] Firebase 서비스 계정 JSON 발급 (백엔드용 — 백엔드 담당이 직접 처리)

---

## P0 — Firebase SDK 셋업 (인프라 검증)

- [x] `pubspec.yaml` 패키지 추가
  - `firebase_core: ^3.6.0`
  - `firebase_messaging: ^15.1.3`
  - `flutter_local_notifications: ^17.2.3`
  - `permission_handler: ^11.3.1`
  - `shared_preferences: ^2.3.2`
- [x] `flutter pub get`
- [x] `lib/firebase_options.dart` 수동 생성 (flutterfire CLI 미설치, plist/json 값 직접 입력)
- [x] Android `settings.gradle.kts` 에 `com.google.gms.google-services:4.4.2` 플러그인 선언
- [x] Android `app/build.gradle.kts` 에 `com.google.gms.google-services` 적용
- [x] iOS `AppDelegate.swift` 에 `import FirebaseCore` + `FirebaseApp.configure()`
- [x] iOS `Info.plist` `UIBackgroundModes: fetch, remote-notification`
- [x] `pod install` (Firebase iOS SDK 11.15.0 설치 완료)
- [x] `main.dart` 에 `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- [x] `flutter analyze` 통과 (기존 경고 1개 외 신규 이슈 없음)
- [x] iOS 실기기 빌드 + 실행 → Firebase 초기화 로그 확인
- [x] Android 디바이스 빌드 + 실행 → Firebase 초기화 로그 확인

---

## P1 — FCM 토큰 + 메시지 수신 (백엔드 무관, 단독 가능)

### 모듈 스캐폴드
- [x] `lib/features/notification/` 디렉토리 생성
- [x] `service/fcm_service.dart`
- [x] `service/local_notification_service.dart`
- [x] `service/push_routing_service.dart`
- [x] `provider/notification_providers.dart` (fcm + local + routing 단일 파일로 통합)

### FCM 기능
- [x] `FcmService.initialize()` — Firebase 권한 요청 (`requestPermission`)
- [x] `FcmService.getToken()` 호출 + 콘솔 출력 (Firebase Console "Send test message" 검증용)
- [x] `onTokenRefresh` 스트림 구독 → 토큰 갱신 시 콜백 (P2 백엔드 등록용 `onTokenIssued` 노출)
- [x] `FirebaseMessaging.onMessage` (포그라운드) → `flutter_local_notifications` 로 표시
- [x] `FirebaseMessaging.onMessageOpenedApp` (백그라운드 → 탭 진입)
- [x] `FirebaseMessaging.instance.getInitialMessage()` (종료 → 탭 진입)
- [x] 백그라운드 핸들러 — top-level `firebaseMessagingBackgroundHandler` + `@pragma('vm:entry-point')`
- [x] `App.initState` 에서 `fcmServiceProvider.initialize()` 호출

### Deep Link 라우팅
- [x] `PushRoutingService.routeFromPayload(Map<String, dynamic> data)` 매핑:
  - `type=A` → `/barcode`
  - `type=B` + `mybookId` → `/main/book-info/{mybookId}` (실제 라우트, 문서 초안 `/mybook` 보정)
  - `type=C` 또는 unknown → `/main/home`
- [x] `go_router` 와 통합 — 전역 `appRouter.go(...)` 사용
- [x] 알림 탭 콜백 3가지(포그라운드/백그라운드/종료) 모두 동일 라우팅 호출
- [x] 단위 테스트 (`test/features/notification/push_routing_service_test.dart` — 9 케이스 통과)

### 검증 (사용자 직접)
- [x] Firebase Console → "Send test message" 로 단말기에 푸시 도달 확인 (iOS 실기기, 2026-05-30)
- [~] 포그라운드/백그라운드/종료 3가지 상태에서 알림 표시/라우팅 동작 확인 (도달 확인 완료, 3상태 매트릭스 검증 진행 예정)

---

## P2 — 백엔드 API 연동 + 설정 UI

**앱 선작업 완료 (2026-05-30).** 백엔드 계약(`damda-server` 설계 문서) 기준으로 앱 코드 구현.
백엔드 미배포 상태라 호출은 graceful 흡수(401/404 → 로컬 fallback). 실서버 통합 검증만 잔여.

### 데이터 레이어
- [x] `lib/data/datasource/notification_remote_datasource.dart` (4 API)
- [x] `lib/data/model/push_settings_model.dart`
- [x] `lib/data/repository/notification_repository_impl.dart`
- [x] `lib/domain/model/push_settings.dart`
- [x] `lib/domain/repository/notification_repository.dart`
- [x] 단위 테스트 — datasource(페이로드 계약) + repository

### 토큰 등록/해제 흐름
- [x] 로그인 성공 후 `POST /notifications/device-token { fcmToken, platform }` (`AuthNotifier._syncPushOnLogin`)
- [x] `onTokenRefresh` / 토큰 발급 시 동일 API 재호출 (`fcmServiceProvider.onTokenIssued`)
- [x] 로그아웃 시 `DELETE /notifications/device-token` + `FirebaseMessaging.deleteToken()` (`_cleanupPushOnLogout`)

### 설정 화면 토글
- [x] `lib/features/settings/screen/settings_screen.dart` 에 "푸시 알림 받기" 항목 + `PixelToggle`
- [x] `lib/features/notification/provider/push_settings_provider.dart`
- [x] 진입 시 `GET /notifications/settings` (실패 시 로컬 fallback)
- [x] 토글 변경 시 `PATCH /notifications/settings` (낙관적 + 흡수)
- [x] OFF 전환 → `deleteToken()` + `DELETE /notifications/device-token` + 로컬 알림 전부 취소
- [x] ON 전환 → OS 권한 확인 → FCM 토큰 재발급 → 서버 등록 + 로컬 알림 재예약

### 권한 UX
- [ ] OS 알림 권한 거부 시 안내 문구 + `app_settings` 패키지 도입 검토
- [ ] Android 13+ `POST_NOTIFICATIONS` 권한 명시적 요청 (현재 `requestPermission` 으로 노출)

### 잔여 (백엔드 배포 후)
- [ ] 실서버 device-token 등록/해제 통합 검증
- [ ] 실서버 `GET/PATCH settings` 동작 검증
- [ ] 서버발 A/B 푸시 + `/notifications/test` 검증

---

## P3 — C 로컬 알림 (백엔드 무관, 단독 가능) — 완료 (2026-05-30)

- [x] `LocalNotificationService.rescheduleC()`
  - 기존 C 알림 예약 취소 (`cancel(cNotificationId)`)
  - `_cDelay`(7일) 뒤 시각으로 `zonedSchedule` 등록
  - 문구 랜덤 선택 (3종)
- [x] `App` 위젯에 `WidgetsBindingObserver` 믹스인 + `didChangeAppLifecycleState`
  - `AppLifecycleState.resumed` 시 `rescheduleC()` (푸시 설정 ON 일 때만)
- [x] `flutter_local_notifications` `onDidReceiveNotificationResponse` → payload `type=C` → `/home`
- [x] 로그아웃 / 푸시 OFF 시 모든 로컬 알림 취소 (`cancelAll`)
- [x] 시간대 처리 (`timezone` 패키지 + `Asia/Seoul` 초기화)
- [x] 검증용: `_cDelay` 상수만 줄이면(7일→1분) 단축 테스트 가능
- [ ] 실기기 E2E (1분 단축으로 C 알림 발동/탭 라우팅 확인) — 사용자 직접

---

## P4 — 안정화

- [ ] Android 알림 채널 등록 (`AndroidNotificationChannel`)
  - 단일 채널 vs A/B/C 분리 의사결정
- [ ] iOS 알림 사운드/배지/카테고리 옵션
- [ ] FCM 무효 토큰 자동 처리 (`MessagingErrorCode` 응답)
- [ ] 에러 핸들링 + 로깅 통일
- [ ] Sentry 등 모니터링 연동 (선택)
- [ ] 단위 테스트 (`fcm_service_test.dart`, `push_routing_service_test.dart`)
- [ ] 통합 검증 — 모든 알림 종류(A/B/C) × 앱 상태 3종 매트릭스

---

## 의사결정 필요

- [ ] Android 알림 채널: 단일 vs A/B/C 분리
- [ ] 로컬 알림 권한 요청 시점: 로그인 직후 vs 첫 사용 vs 설정 화면 진입
- [x] iOS APNs 키 Firebase Console 업로드 완료 → 운영 환경(TestFlight/App Store) 검증은 별도

---

## 진행 메모

- 2026-05-28
  - P0 셋업 진행 (이 시점까지 완료된 내용은 위 체크박스 참고)
  - 다음 행동: APNs 키 Firebase Console 업로드 → 실기기 빌드 검증 → P1 진입

- 2026-05-30 — iOS 실기기 푸시 도달 성공. 막혔던 원인 4종 해결:
  1. `aps-environment` entitlement 누락 → APNS 토큰 미발급. Runner.entitlements 에 `development` 추가.
  2. 신형 엔진 델리게이트(`FlutterImplicitEngineDelegate`)에서 firebase swizzling 이 APNS
     등록 콜백을 안 잡음 → AppDelegate 에 `registerForRemoteNotifications` + `didRegister...`
     명시 구현, `Messaging.apnsToken` 직접 전달.
  3. **APNs 환경 불일치 (핵심)**: `#if DEBUG` 가 이 프로젝트에서 false 로 평가돼 토큰 type 을
     prod 로 등록 → 개발서명(sandbox) 기기에 FCM 이 prod APNs 로 전송 → 무성 드랍.
     embedded.mobileprovision 의 aps-environment 를 런타임에 읽어 sandbox/prod 자동 판정.
     (주의: 프로비저닝 파일은 CMS 바이너리 → `.ascii` 디코딩은 nil → `.isoLatin1` 필수.)
  4. 토큰 재발급 엔드포인트 오타: `/members/reissue` → `/auth/reissue` (Android 원본 일치).
  - 남은 행동: 포그라운드/백그라운드/종료 3상태 + 딥링크(type A/B/C) 매트릭스 검증, 이후 P2 진입.
