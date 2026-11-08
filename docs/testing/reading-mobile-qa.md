# 독서 화면 기기 검증

## 자동 테스트와 분석

```sh
flutter test --no-pub
flutter analyze --no-pub
```

`test/core/network/token_refresh_interceptor_test.dart`는 모의 서버로 재발급 동시 요청·서버 장애·로그인 만료와 원문 로거 미설치를 검증한다. 계정 교체는 `test/data/repository/auth_repository_test.dart`, 로그인·회원가입의 중복 제출과 키보드는 `test/features/auth/auth_screens_test.dart`로 검증한다. 실제 OAuth 로그인 검증과는 다르다.

## 기기 페이지 전환·성능

**개인 기기에서는 반드시 `--keep-app-running`을 사용한다.** `flutter drive`의 기본 종료 처리는 앱을 제거하므로 로컬 로그인과 캐시가 초기화된다. 이번 검증에서 이 동작으로 Android 재로그인이 필요해졌다. 앱 데이터 복원이 아닌 정상 앱 업데이트 설치로 마무리해야 한다.

```sh
flutter drive --profile --no-dds --keep-app-running \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/library_device_test.dart \
  -d DEVICE_ID --dart-define-from-file=env/prod.json
```

기본값은 서버에 접근하지 않는 90권 샘플 서가다. 실제 계정의 읽기 전용 검증에는 이미 로그인된 테스트 기기에서 `--dart-define=LIVE_ACCOUNT_QA=true`를 추가한다. 로그인돼 있지 않으면 명시적으로 실패한다. 헤더·토큰·본문은 수집하지 않고 API 경로와 권수/쪽수만 결과에 기록한다. 샘플에서 API 요청 없음은 실계정 서버 요청 검증을 대신하지 않는다.

iOS 시뮬레이터는 위 명령의 `--profile`을 `--debug`로 바꾼다. Debug에서는 기능만 검증하며 성능 수치로 비교하지 않는다. Profile에서 `--no-dds`는 앱 내부의 VM 서비스 접근 실패를 피하기 위해 사용한다.

결과는 기본적으로 `build/integration_results/`에 생성한다. 다른 위치가 필요하면 `MOABOOK_QA_OUTPUT` 환경 변수로 지정한다. 프레임 지연은 UI 구성과 GPU 그리기를 나누어 해석하며 한쪽 평균 개선을 전체 끊김 해결로 보고하지 않는다.

## 사진 저장

```sh
flutter drive --profile --no-dds --keep-app-running \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/reading_export_test.dart \
  -d DEVICE_ID --dart-define-from-file=env/prod.json
```

사진 추가 권한이 있는 테스트 기기에서 검증용 PNG 1장을 실제 보관함에 저장한다. 계정·책·기록은 수정하지 않는다. iOS 시뮬레이터는 Debug로 실행한다. 개인 기기의 권한 안내와 실제 소셜 로그인 입력은 사용자가 수행한다.

## 정상 앱 복구

기기 테스트 앱 대신 `lib/main.dart`의 정상 빌드를 설치한다. Android는 동일 서명의 APK를 `adb install --no-streaming -r`로 업데이트하며 앱 제거·데이터 삭제 명령을 사용하지 않는다. iOS는 정상 Release 빌드를 설치한다. 스토어 배포는 별도 절차다.
