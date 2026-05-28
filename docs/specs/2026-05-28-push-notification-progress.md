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
- [ ] Firebase Console → Cloud Messaging → APNs Authentication Key 업로드
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
- [ ] `lib/features/notification/` 디렉토리 생성
- [ ] `service/fcm_service.dart`
- [ ] `service/local_notification_service.dart`
- [ ] `service/push_routing_service.dart`
- [ ] `provider/fcm_provider.dart`
- [ ] `provider/local_notification_provider.dart`

### FCM 기능
- [ ] `FcmService.initialize()` — Firebase 권한 요청 (`requestPermission`)
- [ ] `FcmService.getToken()` 호출 + 콘솔 출력 (Firebase Console "Send test message" 검증용)
- [ ] `onTokenRefresh` 스트림 구독 → 토큰 갱신 시 콜백
- [ ] `FirebaseMessaging.onMessage` (포그라운드) → `flutter_local_notifications` 로 표시
- [ ] `FirebaseMessaging.onMessageOpenedApp` (백그라운드 → 탭 진입)
- [ ] `FirebaseMessaging.instance.getInitialMessage()` (종료 → 탭 진입)
- [ ] 백그라운드 핸들러 — top-level 함수 + `@pragma('vm:entry-point')`
- [ ] 로그인 직후 트리거 — `auth_provider` 또는 `App` `initState` 에서 `FcmService.initialize()` 호출

### Deep Link 라우팅
- [ ] `PushRoutingService.routeFromPayload(Map<String, dynamic> data)` 매핑:
  - `type=A` → `/barcode`
  - `type=B` + `mybookId` → `/mybook/{mybookId}`
  - 로컬 (C) → `/home`
- [ ] `go_router` 와 통합 (글로벌 navigator key 또는 `appRouter.go(...)`)
- [ ] 알림 탭 콜백에서 라우팅 호출

### 검증
- [ ] Firebase Console → "Send test message" 로 단말기에 푸시 도달 확인
- [ ] 포그라운드/백그라운드/종료 3가지 상태에서 알림 표시/라우팅 동작 확인

---

## P2 — 백엔드 API 연동 + 설정 UI

**의존성: 백엔드 P0 (`POST/DELETE /notifications/device-token`, `GET/PATCH /notifications/settings`) 완료 필요.**

### 데이터 레이어
- [!] `lib/data/datasource/notification_remote_datasource.dart`
- [!] `lib/data/model/push_settings_model.dart`
- [!] `lib/data/repository/notification_repository_impl.dart`
- [!] `lib/domain/model/push_settings.dart`
- [!] `lib/domain/repository/notification_repository.dart`

### 토큰 등록/해제 흐름
- [!] 로그인 성공 후 `POST /notifications/device-token { fcmToken, platform }`
- [!] `onTokenRefresh` 시 동일 API 재호출
- [!] 로그아웃 시 `DELETE /notifications/device-token` + `FirebaseMessaging.deleteToken()`

### 설정 화면 토글
- [!] `lib/features/settings/screen/settings_screen.dart` 에 "푸시 알림 받기" 항목 추가
- [!] `lib/features/notification/provider/push_settings_provider.dart`
- [!] 진입 시 `GET /notifications/settings`
- [!] 토글 변경 시 `PATCH /notifications/settings`
- [!] OFF 전환 → `deleteToken()` + `DELETE /notifications/device-token` + 로컬 알림 전부 취소
- [!] ON 전환 → OS 권한 확인 → FCM 토큰 재발급 → 서버 등록 + 로컬 알림 재예약

### 권한 UX
- [ ] OS 알림 권한 거부 시 안내 문구 + `app_settings` 패키지 도입 검토
- [ ] Android 13+ `POST_NOTIFICATIONS` 권한 명시적 요청

---

## P3 — C 로컬 알림 (백엔드 무관, 단독 가능)

- [ ] `LocalNotificationService.rescheduleC()`
  - 기존 C 알림 예약 취소
  - 7일 뒤 시각으로 `zonedSchedule` 등록
  - 문구 랜덤 선택 (3종)
- [ ] `App` 위젯에 `WidgetsBindingObserver` 믹스인 + `didChangeAppLifecycleState`
  - `AppLifecycleState.resumed` 시 `rescheduleC()` 호출
- [ ] `flutter_local_notifications` `onDidReceiveNotificationResponse` 콜백 → `/home` 라우팅
- [ ] 로그아웃 / 푸시 OFF 시 모든 C 예약 취소
- [ ] 시간대 처리 (`timezone` 패키지 초기화 — KST 가정)
- [ ] 검증: 시각 단축(7일 → 1분) 변수로 테스트 가능하게 설계

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
- [ ] iOS APNs 키 Firebase Console 업로드 → 운영 환경(TestFlight/App Store) 검증 필요

---

## 진행 메모

- 2026-05-28
  - P0 셋업 진행 (이 시점까지 완료된 내용은 위 체크박스 참고)
  - 다음 행동: APNs 키 Firebase Console 업로드 → 실기기 빌드 검증 → P1 진입
