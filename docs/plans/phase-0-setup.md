# Phase 0: 프로젝트 셋업 + Identity 잠금

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Spec:** `docs/superpowers/specs/2026-05-25-flutter-rebuild-design.md`
> **Roadmap:** `docs/superpowers/plans/2026-05-25-flutter-rebuild-roadmap.md`

**Goal:** 빈 Flutter 프로젝트를 생성하고, Android/iOS 양쪽의 패키지명·번들 ID·서명·버전을 기존 스토어 식별자에 정확히 맞춘 뒤 CI Identity Gate를 통과시킨다. Phase 1 이후의 모든 작업이 이 토대 위에 쌓인다.

**Architecture:** `~/dev/moabook-app`에 신규 Flutter 프로젝트. Android `applicationId = project.side.ikdaman` (versionCode 23), iOS `PRODUCT_BUNDLE_IDENTIFIER = com.gogochang.Ikdaman`. 기존 `release.keystore` 이식으로 AAB 서명 SHA가 v1.0.22와 동일해야 함.

**Tech Stack:** Flutter 3.x stable, Dart 3.x, GitHub Actions, fastlane (이 phase에선 사용 안 함), apksigner (Android SDK bundletool 포함)

---

## 선행 작업 체크

- [ ] `flutter doctor` 에 Android SDK, Xcode, CocoaPods 모두 녹색인지 확인
  ```bash
  flutter doctor -v
  ```
  Expected: `[✓] Flutter` `[✓] Android toolchain` `[✓] Xcode` 모두 녹색. 빨간 항목 있으면 먼저 해결 후 진행.

- [ ] 기존 Android `release.keystore` 와 `key.properties` 위치 확인
  ```bash
  ls ~/dev/moabook/release.keystore ~/dev/moabook/key.properties
  ```
  Expected: 두 파일 모두 존재. 없으면 진행 불가 — 키스토어 없이는 서명 불가.

- [ ] App Store Connect에서 현재 iOS 빌드 번호(CFBundleVersion) 확인
  브라우저에서 `https://appstoreconnect.apple.com` → 앱 선택 → TestFlight/제출 이력에서 마지막 빌드 번호 확인.
  예: 마지막 빌드 번호가 `5`이면 이 Phase에서 `6`으로 설정.
  **확인한 값을 메모해 두세요** — Task 5에서 사용.

- [ ] **인프라 선행 작업 (§7 참고)** — Phase 0 시작 전 완료:
  - GitHub repo 2개 생성: `moabook-app` (private), `moabook_ios_private` (private, 비어있어도 됨)
  - App Store Connect 사용자 및 접근 → 통합 → 키 `35SHWLN842` 권한이 "앱 관리자"인지 확인
  - Play Console → 설정 → API 액세스 → 기존 서비스 계정에 moabook 앱 권한 추가
  - korean_learning에서 쓰는 GitHub PAT가 `moabook_ios_private`에도 접근 가능한지 확인

---

## Task 1: Compose 베이스라인 스크린샷 캡쳐

> 코드 작업 없음. Android 기기에서 v1.0.22 현재 모습을 찍어두는 것이 목적.

**Files:**
- Create: `~/dev/moabook/screenshots/baseline/` (폴더만)

- [ ] **Step 1: 폴더 생성**
  ```bash
  mkdir -p ~/dev/moabook/screenshots/baseline
  ```

- [ ] **Step 2: 테스트 계정 준비**
  Android 기기에서 앱 실행 → 로그인. 책이 7권 이상 등록된 상태 확인. 없으면 책 등록 후 진행.

- [ ] **Step 3: 시스템 UI 숨기기 (상태바/네비게이션 바 제거)**
  ```bash
  adb shell settings put global policy_control immersive.full=*
  ```
  앱을 완전히 재시작해서 시스템 UI가 사라진 것을 확인.

- [ ] **Step 4: 화면 15개 캡쳐**
  각 화면 진입 후 아래 명령으로 캡쳐 (`<name>` 부분만 바꿔서 실행):
  ```bash
  adb exec-out screencap -p > ~/dev/moabook/screenshots/baseline/<name>.png
  ```

  | 캡쳐 파일명 | 진입 방법 | 데이터 상태 |
  |---|---|---|
  | `splash.png` | 앱 재시작 직후 1초 안에 | - |
  | `login.png` | 로그아웃 후 로그인 화면 | 입력 없음 |
  | `signup.png` | 회원가입 화면 | 닉네임 입력 중 |
  | `home__filled.png` | 홈 탭 | 책 7권 이상 |
  | `home__empty.png` | 새 계정 로그인 후 홈 | 책 없음 |
  | `book_search__results.png` | 검색 탭 → "파친코" 검색 | 결과 있음 |
  | `book_search__empty.png` | 검색 탭 → "zzzznotexist" 검색 | 결과 없음 |
  | `add_book.png` | 검색 결과에서 책 선택 | 책 선택된 상태 |
  | `manual_book_input.png` | 직접 입력 화면 | 제목 입력 중 |
  | `book_info.png` | 등록된 책 탭 | 상세 정보 있음 |
  | `my_book_search.png` | 내 책 검색 | 결과 있음 |
  | `history__filled.png` | 히스토리 탭 | 데이터 있음 |
  | `history__empty.png` | 새 계정으로 히스토리 | 빈 상태 |
  | `settings.png` | 설정 탭 | 기본 |
  | `nickname_change.png` | 설정 → 닉네임 변경 | 현재 닉네임 표시 |

- [ ] **Step 5: 시스템 UI 복원**
  ```bash
  adb shell settings delete global policy_control
  ```

- [ ] **Step 6: 캡쳐 결과 확인**
  ```bash
  ls ~/dev/moabook/screenshots/baseline/ | wc -l
  ```
  Expected: `15` 이상.

- [ ] **Step 7: .gitignore에 screenshots 추가 (용량 큼)**
  `~/dev/moabook/.gitignore` 에 아래 추가:
  ```
  screenshots/
  ```
  ```bash
  echo "screenshots/" >> ~/dev/moabook/.gitignore
  git -C ~/dev/moabook add .gitignore && git -C ~/dev/moabook commit -m "chore: ignore screenshots folder"
  ```

---

## Task 2: Flutter 프로젝트 생성

**Files:**
- Create: `~/dev/moabook-app/` (전체 Flutter 프로젝트)

- [ ] **Step 1: flutter create**
  ```bash
  cd ~/dev
  flutter create \
    --org project.side \
    --project-name moabook \
    --platforms android,ios \
    ~/dev/moabook-app
  ```
  Expected: `All done!` 출력. `~/dev/moabook-app/` 생성됨.

- [ ] **Step 2: 기본 counter 앱 코드 제거**
  `lib/main.dart` 를 아래로 교체:
  ```dart
  import 'package:flutter/material.dart';

  void main() {
    runApp(const App());
  }

  class App extends StatelessWidget {
    const App({super.key});

    @override
    Widget build(BuildContext context) {
      return const MaterialApp(
        title: '모아북',
        home: Scaffold(
          body: Center(child: Text('모아북')),
        ),
      );
    }
  }
  ```

- [ ] **Step 3: test/widget_test.dart 초기화**
  ```dart
  // test/widget_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:moabook/main.dart';

  void main() {
    testWidgets('App smoke test', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.text('모아북'), findsOneWidget);
    });
  }
  ```

- [ ] **Step 4: 테스트 통과 확인**
  ```bash
  cd ~/dev/moabook-app
  flutter test
  ```
  Expected: `All tests passed!`

- [ ] **Step 5: git 초기화 + 첫 커밋**
  ```bash
  cd ~/dev/moabook-app
  git init
  git add .
  git commit -m "chore: flutter create (org=project.side, name=moabook)"
  ```

---

## Task 2.5: fastlane + match 셋업 (iOS 자동배포 인프라)

> korean_learning 의 fastlane 자산을 복사 후 식별자만 교체. iOS Apple Developer 인증서/프로파일을 `moabook_ios_private` repo에 암호화 저장.

**Files:**
- Create: `ios/Gemfile`
- Create: `ios/fastlane/Appfile`
- Create: `ios/fastlane/Matchfile`
- Create: `ios/fastlane/Fastfile`
- Create: `android/fastlane/Appfile`
- Create: `android/fastlane/Fastfile`
- Create: `android/Gemfile`

- [ ] **Step 1: ios/Gemfile 생성**
  ```bash
  cd ~/dev/moabook-app/ios
  cat > Gemfile << 'EOF'
  source "https://rubygems.org"
  gem "fastlane"
  EOF
  ```

- [ ] **Step 2: ios/fastlane/ 폴더 + Appfile 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/ios/fastlane
  cat > ~/dev/moabook-app/ios/fastlane/Appfile << 'EOF'
  app_identifier("com.gogochang.Ikdaman")
  apple_id(ENV["APPLE_ID"] || "")
  itc_team_id(ENV["ITC_TEAM_ID"] || "")
  team_id("T583WJWNAK")
  EOF
  ```

- [ ] **Step 3: ios/fastlane/Matchfile 생성**
  ```bash
  cat > ~/dev/moabook-app/ios/fastlane/Matchfile << 'EOF'
  git_url("https://github.com/ikdaman/moabook_ios_private.git")
  storage_mode("git")
  type("appstore")
  app_identifier(["com.gogochang.Ikdaman"])
  team_id("T583WJWNAK")
  EOF
  ```
  > match repo는 이미 `~/dev/moabook_ios_private`에 초기화돼있음 (main 브랜치, README 1커밋).

- [ ] **Step 4: ios/fastlane/Fastfile 생성 (korean_learning에서 복사)**
  ```bash
  cp ~/dev/korean_learning/ios/fastlane/Fastfile ~/dev/moabook-app/ios/fastlane/Fastfile
  ```
  그리고 식별자만 교체:
  ```bash
  cd ~/dev/moabook-app/ios/fastlane
  sed -i '' 's/com\.boringkm\.koreanLearning/com.gogochang.Ikdaman/g' Fastfile
  sed -i '' 's/match AppStore com.gogochang.Ikdaman/match AppStore com.gogochang.Ikdaman/g' Fastfile
  ```
  > Fastfile 내부의 `key_id`, `issuer_id`, `team_id` 는 환경변수 fallback 으로 동일 (korean_learning 그대로). API Key 재사용 OK.

- [ ] **Step 5: bundle install**
  ```bash
  cd ~/dev/moabook-app/ios
  bundle install
  ```
  Expected: `Bundle complete!`

- [ ] **Step 6: API Key .p8 파일 임시 복사 (match 실행용)**
  ```bash
  cp ~/dev/korean_learning/ios/fastlane/AuthKey_35SHWLN842.p8 \
     ~/dev/moabook-app/ios/fastlane/AuthKey_35SHWLN842.p8
  ```
  > 이 파일은 절대 commit X — .gitignore 확인.

- [ ] **Step 7: ios/.gitignore 확인 (AuthKey 제외)**
  ```bash
  grep "AuthKey\|\.p8" ~/dev/moabook-app/ios/.gitignore || \
    echo -e "\nfastlane/AuthKey_*.p8" >> ~/dev/moabook-app/ios/.gitignore
  ```

- [ ] **Step 8: match appstore 실행 (인증서 + 프로파일 생성)**
  ```bash
  cd ~/dev/moabook-app/ios
  export APP_STORE_KEY_ID=35SHWLN842
  export APP_STORE_ISSUER_ID=e7624601-1e53-41bd-b54d-7bf952728abd
  export APP_STORE_KEY_PATH=fastlane/AuthKey_35SHWLN842.p8
  export MATCH_PASSWORD="<korean_learning에서 쓰던 값>"
  bundle exec fastlane match appstore
  ```
  Expected:
  - `moabook_ios_private` repo에 암호화된 인증서/프로파일 push
  - 로컬 Keychain에 cert 설치
  - 출력 마지막에 `Profile UUID:` 와 함께 `Successfully...` 메시지

- [ ] **Step 9: Android fastlane 셋업 (korean_learning 패턴)**
  ```bash
  mkdir -p ~/dev/moabook-app/android/fastlane
  cp ~/dev/korean_learning/android/Gemfile ~/dev/moabook-app/android/Gemfile
  cp ~/dev/korean_learning/android/fastlane/Fastfile ~/dev/moabook-app/android/fastlane/Fastfile

  # Appfile은 package_name 만 교체
  cat > ~/dev/moabook-app/android/fastlane/Appfile << 'EOF'
  json_key_file(ENV["PLAY_STORE_CONFIG_JSON_PATH"] || "play-store-credentials.json")
  package_name("project.side.ikdaman")
  EOF
  ```

- [ ] **Step 10: android/.gitignore — play-store-credentials.json 추가**
  ```bash
  echo "play-store-credentials.json" >> ~/dev/moabook-app/android/.gitignore
  echo "upload-keystore.jks" >> ~/dev/moabook-app/android/.gitignore
  ```

- [ ] **Step 11: 커밋 (민감 파일 staged 안 됐는지 git status로 확인)**
  ```bash
  cd ~/dev/moabook-app
  git add ios/Gemfile ios/fastlane/Appfile ios/fastlane/Matchfile ios/fastlane/Fastfile ios/.gitignore
  git add android/Gemfile android/fastlane/Appfile android/fastlane/Fastfile android/.gitignore
  git status   # AuthKey_*.p8, play-store-credentials.json 이 staged 안 됨을 반드시 확인
  git commit -m "chore(ci): set up fastlane + match (reusing korean_learning patterns)"
  ```

---

## Task 3: Android applicationId · namespace · 버전 수정

**Files:**
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: build.gradle.kts 확인**
  ```bash
  grep -n "applicationId\|namespace\|versionCode\|versionName" ~/dev/moabook-app/android/app/build.gradle.kts
  ```
  Expected: `applicationId = "project.side.moabook"` 등 flutter create 기본값 확인.

- [ ] **Step 2: android/app/build.gradle.kts 수정**
  `android { ... }` 블록의 상단과 `defaultConfig` 를 아래와 같이 수정:
  ```kotlin
  android {
      namespace = "project.side.ikdaman"

      defaultConfig {
          applicationId = "project.side.ikdaman"
          minSdk = 29
          targetSdk = 36
          versionCode = 23
          versionName = "2.0.0"
          // ...나머지 기존 내용 유지
      }
  ```
  (`compileSdk`, `minSdk` 등 나머지 값은 그대로 유지)

- [ ] **Step 3: MainActivity.kt 패키지 경로 확인**
  flutter create 기본 경로가 `project/side/moabook/` 이므로 kotlinOptions 에서 패키지 선언 확인:
  ```bash
  cat ~/dev/moabook-app/android/app/src/main/kotlin/project/side/moabook/MainActivity.kt
  ```
  `package project.side.moabook` → `package project.side.ikdaman` 으로 변경, 파일 경로도 `ikdaman/` 으로 이동:
  ```bash
  mkdir -p ~/dev/moabook-app/android/app/src/main/kotlin/project/side/ikdaman
  mv ~/dev/moabook-app/android/app/src/main/kotlin/project/side/moabook/MainActivity.kt \
     ~/dev/moabook-app/android/app/src/main/kotlin/project/side/ikdaman/MainActivity.kt
  sed -i '' 's/package project.side.moabook/package project.side.ikdaman/' \
     ~/dev/moabook-app/android/app/src/main/kotlin/project/side/ikdaman/MainActivity.kt
  rmdir ~/dev/moabook-app/android/app/src/main/kotlin/project/side/moabook 2>/dev/null || true
  ```

- [ ] **Step 4: AndroidManifest 패키지 제거 (Flutter 3.x는 namespace 우선)**
  ```bash
  grep "package=" ~/dev/moabook-app/android/app/src/main/AndroidManifest.xml
  ```
  `package=` 속성이 있으면 제거 (Flutter 신규 프로젝트는 없는 경우가 많음).

- [ ] **Step 5: applicationId 검증**
  ```bash
  grep 'applicationId\|namespace' ~/dev/moabook-app/android/app/build.gradle.kts
  ```
  Expected:
  ```
  namespace = "project.side.ikdaman"
  applicationId = "project.side.ikdaman"
  ```

- [ ] **Step 6: debug 빌드로 동작 확인**
  ```bash
  cd ~/dev/moabook-app
  flutter build apk --debug
  ```
  Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 7: 커밋**
  ```bash
  git add android/
  git commit -m "fix(android): set applicationId=project.side.ikdaman, versionCode=23, versionName=2.0.0"
  ```

---

## Task 4: Android 서명 키 이식 + 릴리즈 빌드 검증

**Files:**
- Create: `android/key.properties` (gitignore)
- Create: `android/key.properties.example`
- Modify: `android/app/build.gradle.kts` (signingConfigs 추가)
- Copy: `release.keystore` → 프로젝트 루트

- [ ] **Step 1: 기존 키스토어 + key.properties 복사**
  ```bash
  cp ~/dev/moabook/release.keystore ~/dev/moabook-app/release.keystore
  cp ~/dev/moabook/key.properties ~/dev/moabook-app/android/key.properties
  ```

- [ ] **Step 2: key.properties.example 생성 (커밋용)**
  ```bash
  cat > ~/dev/moabook-app/android/key.properties.example << 'EOF'
  KEYSTORE_PASSWORD=YOUR_KEYSTORE_PASSWORD
  KEY_ALIAS=YOUR_KEY_ALIAS
  KEY_PASSWORD=YOUR_KEY_PASSWORD
  KAKAO_APP_KEY=YOUR_KAKAO_APP_KEY
  NAVER_CLIENT_ID=YOUR_NAVER_CLIENT_ID
  NAVER_CLIENT_SECRET=YOUR_NAVER_CLIENT_SECRET
  BASE_URL=https://moabook.shop
  EOF
  ```

- [ ] **Step 3: .gitignore 에 민감 파일 추가**
  `~/dev/moabook-app/.gitignore` 에 아래 추가:
  ```
  release.keystore
  android/key.properties
  env/
  ```

- [ ] **Step 4: build.gradle.kts 에 signingConfigs 추가**
  `android/app/build.gradle.kts` 상단에 import 추가, `android { }` 안에 삽입:
  ```kotlin
  import java.util.Properties

  // android { } 블록 안, defaultConfig 위에 삽입:

  val keyProps = Properties()
  val keyPropsFile = rootProject.file("android/key.properties")
  if (keyPropsFile.exists()) {
      keyProps.load(keyPropsFile.inputStream())
  }

  // signingConfigs 블록 (buildTypes 위에):
  signingConfigs {
      create("release") {
          storeFile = rootProject.file("release.keystore")
          storePassword = keyProps.getProperty("KEYSTORE_PASSWORD", "")
          keyAlias = keyProps.getProperty("KEY_ALIAS", "")
          keyPassword = keyProps.getProperty("KEY_PASSWORD", "")
      }
  }

  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("release")
          isMinifyEnabled = false  // Phase 0에서는 false, 출시 전 true로 변경
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      }
  }
  ```

- [ ] **Step 5: 릴리즈 AAB 빌드**
  ```bash
  cd ~/dev/moabook-app
  flutter build appbundle --release
  ```
  Expected: `Built build/app/outputs/bundle/release/app-release.aab`

- [ ] **Step 6: 서명 SHA 확인 (기존 v1.0.22 APK와 비교)**
  먼저 기존 v1.0.22 APK 또는 AAB의 SHA 확인 (Play Console → 앱 서명 → 업로드 인증서 SHA-1):
  ```bash
  # 새 AAB 서명 SHA 출력
  cd ~/dev/moabook-app
  bundletool build-apks \
    --bundle=build/app/outputs/bundle/release/app-release.aab \
    --output=/tmp/moabook.apks \
    --mode=universal \
    --ks=release.keystore \
    --ks-pass=pass:$(grep KEYSTORE_PASSWORD android/key.properties | cut -d= -f2) \
    --ks-key-alias=$(grep KEY_ALIAS android/key.properties | cut -d= -f2) \
    --key-pass=pass:$(grep KEY_PASSWORD android/key.properties | cut -d= -f2)
  unzip -p /tmp/moabook.apks universal.apks | \
    apksigner verify --print-certs - | grep "Signer #1 certificate SHA-256"
  ```
  **Play Console의 SHA-256과 일치하는지 눈으로 확인.** 불일치 시 keystore 파일이 잘못된 것.

- [ ] **Step 7: 커밋**
  ```bash
  cd ~/dev/moabook-app
  git add android/app/build.gradle.kts android/key.properties.example .gitignore
  git commit -m "feat(android): add release signing config, keystore gitignored"
  ```
  > ⚠ `release.keystore`, `android/key.properties` 는 절대 commit 하지 않음.
  > `git status` 로 staged 목록에 없는지 확인 후 커밋.

---

## Task 5: iOS 번들 ID · 버전 수정

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: 기존 번들 ID 확인**
  ```bash
  grep "PRODUCT_BUNDLE_IDENTIFIER" ~/dev/moabook-app/ios/Runner.xcodeproj/project.pbxproj
  ```
  Expected: `PRODUCT_BUNDLE_IDENTIFIER = project.side.moabook;` 여러 줄.

- [ ] **Step 2: 번들 ID 교체**
  ```bash
  cd ~/dev/moabook-app
  sed -i '' \
    's/PRODUCT_BUNDLE_IDENTIFIER = project\.side\.moabook;/PRODUCT_BUNDLE_IDENTIFIER = com.gogochang.Ikdaman;/g' \
    ios/Runner.xcodeproj/project.pbxproj

  # RunnerTests 번들 ID (Tests target)
  sed -i '' \
    's/PRODUCT_BUNDLE_IDENTIFIER = com\.gogochang\.Ikdaman\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = com.gogochang.IkdamanTests;/g' \
    ios/Runner.xcodeproj/project.pbxproj
  ```
  > Tests target은 `com.gogochang.IkdamanTests` (RunnerTests suffix 붙임).
  > sed 치환 순서가 중요 — Tests 먼저 하면 안 됨.

- [ ] **Step 3: 버전 수정 (pbxproj)**
  ```bash
  # MARKETING_VERSION = 앱 버전
  sed -i '' \
    's/MARKETING_VERSION = 1\.0;/MARKETING_VERSION = 2.0.0;/g' \
    ios/Runner.xcodeproj/project.pbxproj

  # CURRENT_PROJECT_VERSION = 빌드 번호 (선행 작업에서 확인한 기존+1)
  # 예: 기존이 5였으면 6으로:
  sed -i '' \
    's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = 6;/g' \
    ios/Runner.xcodeproj/project.pbxproj
  ```
  > `CURRENT_PROJECT_VERSION` 값은 선행 작업에서 확인한 값 + 1로 수정.

- [ ] **Step 4: Info.plist 버전 동기화 확인**
  ```bash
  grep -A1 "CFBundleShortVersionString\|CFBundleVersion" ~/dev/moabook-app/ios/Runner/Info.plist
  ```
  Flutter 신규 프로젝트는 `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` 변수 참조. 이 경우 pbxproj 수정만으로 충분.
  만약 하드코딩 값이면:
  ```bash
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 2.0.0" ios/Runner/Info.plist
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 6" ios/Runner/Info.plist
  ```

- [ ] **Step 5: 번들 ID 검증**
  ```bash
  grep "PRODUCT_BUNDLE_IDENTIFIER" ~/dev/moabook-app/ios/Runner.xcodeproj/project.pbxproj
  ```
  Expected: `com.gogochang.Ikdaman` 만 나와야 함. `project.side.moabook` 없어야 함.

- [ ] **Step 6: iOS 시뮬레이터 빌드 확인**
  ```bash
  cd ~/dev/moabook-app
  flutter build ios --simulator
  ```
  Expected: `Build Succeeded`

- [ ] **Step 7: 커밋**
  ```bash
  git add ios/
  git commit -m "fix(ios): set bundle ID=com.gogochang.Ikdaman, version=2.0.0, build=6"
  ```

---

## Task 6: 앱 표시명 "모아북"

**Files:**
- Modify: `android/app/src/main/res/values/strings.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Android 앱 이름 수정**
  `android/app/src/main/res/values/strings.xml` 내용:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <resources>
      <string name="app_name">모아북</string>
  </resources>
  ```

- [ ] **Step 2: iOS 앱 이름 수정**
  ```bash
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 모아북" ~/dev/moabook-app/ios/Runner/Info.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 모아북" ~/dev/moabook-app/ios/Runner/Info.plist
  ```

- [ ] **Step 3: 검증**
  ```bash
  grep "모아북\|app_name" ~/dev/moabook-app/android/app/src/main/res/values/strings.xml
  grep "CFBundleDisplayName" -A1 ~/dev/moabook-app/ios/Runner/Info.plist
  ```
  Expected: 양쪽 모두 "모아북" 출력.

- [ ] **Step 4: 커밋**
  ```bash
  cd ~/dev/moabook-app
  git add android/app/src/main/res/values/strings.xml ios/Runner/Info.plist
  git commit -m "feat: set app display name to 모아북 on both platforms"
  ```

---

## Task 7: env 시스템 구축

**Files:**
- Create: `env/prod.json` (gitignore, 실제 키)
- Create: `env/prod.json.example` (커밋용 스키마)
- Create: `lib/core/env/env.dart`

- [ ] **Step 1: env 폴더 + prod.json.example 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/env
  cat > ~/dev/moabook-app/env/prod.json.example << 'EOF'
  {
    "KAKAO_APP_KEY": "YOUR_KAKAO_APP_KEY",
    "NAVER_CLIENT_ID": "YOUR_NAVER_CLIENT_ID",
    "NAVER_CLIENT_SECRET": "YOUR_NAVER_CLIENT_SECRET",
    "BASE_URL": "https://moabook.shop"
  }
  EOF
  ```

- [ ] **Step 2: 실제 prod.json 생성 (기존 key.properties 에서 값 옮기기)**
  기존 `~/dev/moabook/key.properties` 에서 해당 값을 복사해서 채움:
  ```bash
  # 기존 값 확인
  cat ~/dev/moabook/key.properties
  ```
  확인한 값으로 `~/dev/moabook-app/env/prod.json` 직접 작성:
  ```json
  {
    "KAKAO_APP_KEY": "<기존 key.properties의 KAKAO_APP_KEY 값>",
    "NAVER_CLIENT_ID": "<기존 NAVER_CLIENT_ID 값>",
    "NAVER_CLIENT_SECRET": "<기존 NAVER_CLIENT_SECRET 값>",
    "BASE_URL": "https://moabook.shop"
  }
  ```

- [ ] **Step 3: .gitignore 에 env/ 추가 확인**
  ```bash
  grep "^env/" ~/dev/moabook-app/.gitignore
  ```
  없으면:
  ```bash
  echo "env/" >> ~/dev/moabook-app/.gitignore
  ```

- [ ] **Step 4: lib/core/env/ 폴더 + env.dart 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/lib/core/env
  ```
  `lib/core/env/env.dart`:
  ```dart
  abstract final class Env {
    static const kakaoAppKey =
        String.fromEnvironment('KAKAO_APP_KEY');
    static const naverClientId =
        String.fromEnvironment('NAVER_CLIENT_ID');
    static const naverClientSecret =
        String.fromEnvironment('NAVER_CLIENT_SECRET');
    static const baseUrl =
        String.fromEnvironment('BASE_URL', defaultValue: 'https://moabook.shop');
  }
  ```

- [ ] **Step 5: env 로딩 단위 테스트**
  `test/core/env/env_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:moabook/core/env/env.dart';

  void main() {
    test('Env.baseUrl has default value', () {
      // dart-define 없을 때 defaultValue 동작 확인
      expect(Env.baseUrl, 'https://moabook.shop');
    });
  }
  ```

- [ ] **Step 6: 테스트 실행**
  ```bash
  cd ~/dev/moabook-app
  flutter test test/core/env/env_test.dart
  ```
  Expected: `All tests passed!`

- [ ] **Step 7: env로 앱 실행 테스트**
  ```bash
  flutter run --dart-define-from-file=env/prod.json
  ```
  Expected: 앱 정상 실행 ("모아북" 텍스트 화면).

- [ ] **Step 8: 커밋**
  ```bash
  cd ~/dev/moabook-app
  git add lib/core/env/ env/prod.json.example test/core/env/ .gitignore
  git commit -m "feat: add env system with dart-define-from-file, Env class"
  ```

---

## Task 8: Identity 검증 스크립트

**Files:**
- Create: `scripts/verify_identity.sh`

- [ ] **Step 1: scripts 폴더 + verify_identity.sh 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/scripts
  ```
  `scripts/verify_identity.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  PASS=true

  check() {
    local label="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
      echo "✓ $label"
    else
      echo "✗ FAIL: $label"
      PASS=false
    fi
  }

  # 1. Android applicationId
  grep -q 'applicationId = "project.side.ikdaman"' \
    "$ROOT/android/app/build.gradle.kts" 2>/dev/null
  check "Android applicationId == project.side.ikdaman" "$?"

  # 2. Android namespace
  grep -q 'namespace = "project.side.ikdaman"' \
    "$ROOT/android/app/build.gradle.kts" 2>/dev/null
  check "Android namespace == project.side.ikdaman" "$?"

  # 3. Android versionCode > 22
  VC=$(grep 'versionCode' "$ROOT/android/app/build.gradle.kts" | grep -o '[0-9]*' | head -1)
  [ "${VC:-0}" -gt 22 ]
  check "Android versionCode ($VC) > 22" "$?"

  # 4. iOS bundle ID
  grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.gogochang.Ikdaman;' \
    "$ROOT/ios/Runner.xcodeproj/project.pbxproj" 2>/dev/null
  check "iOS PRODUCT_BUNDLE_IDENTIFIER == com.gogochang.Ikdaman" "$?"

  # 5. project.side.moabook (flutter create 기본값) 잔재 없음
  ! grep -q 'project\.side\.moabook' \
    "$ROOT/android/app/build.gradle.kts" 2>/dev/null
  check "No project.side.moabook remnants in build.gradle.kts" "$?"

  if [ "$PASS" = "true" ]; then
    echo ""
    echo "All identity checks passed ✓"
    exit 0
  else
    echo ""
    echo "Identity check FAILED ✗"
    exit 1
  fi
  ```

- [ ] **Step 2: 실행 권한 부여**
  ```bash
  chmod +x ~/dev/moabook-app/scripts/verify_identity.sh
  ```

- [ ] **Step 3: 스크립트 실행 확인**
  ```bash
  cd ~/dev/moabook-app
  bash scripts/verify_identity.sh
  ```
  Expected:
  ```
  ✓ Android applicationId == project.side.ikdaman
  ✓ Android namespace == project.side.ikdaman
  ✓ Android versionCode (23) > 22
  ✓ iOS PRODUCT_BUNDLE_IDENTIFIER == com.gogochang.Ikdaman
  ✓ No project.side.moabook remnants in build.gradle.kts

  All identity checks passed ✓
  ```

- [ ] **Step 4: 커밋**
  ```bash
  cd ~/dev/moabook-app
  git add scripts/verify_identity.sh
  git commit -m "feat(ci): add identity verification script"
  ```

---

## Task 9: GitHub Actions — Identity Gate 워크플로

**Files:**
- Create: `.github/workflows/identity-gate.yml`

- [ ] **Step 1: .github/workflows 폴더 생성**
  ```bash
  mkdir -p ~/dev/moabook-app/.github/workflows
  ```

- [ ] **Step 2: identity-gate.yml 작성**
  `.github/workflows/identity-gate.yml`:
  ```yaml
  name: Identity Gate

  on:
    push:
      branches: [main, master]
    pull_request:
      branches: [main, master]

  jobs:
    identity-and-test:
      runs-on: ubuntu-latest

      steps:
        - uses: actions/checkout@v4

        - uses: subosito/flutter-action@v2
          with:
            channel: stable
            cache: true

        - name: Install dependencies
          run: flutter pub get

        - name: Verify identity
          run: bash scripts/verify_identity.sh

        - name: Flutter analyze
          run: flutter analyze --fatal-infos

        - name: Flutter test
          run: flutter test --coverage

    build-android:
      runs-on: ubuntu-latest
      needs: identity-and-test
      # release 서명은 secrets 세팅 후 활성화 (Task 9 Step 3 참조)
      # 지금은 debug 빌드로 빌드 가능 여부만 확인
      steps:
        - uses: actions/checkout@v4

        - uses: subosito/flutter-action@v2
          with:
            channel: stable
            cache: true

        - name: Install dependencies
          run: flutter pub get

        - name: Build APK (debug)
          run: flutter build apk --debug
  ```
  > iOS 빌드는 `macos-latest` runner + 인증서 secrets 필요 → Phase 6(출시 준비)에서 추가.

- [ ] **Step 3: GitHub repository secrets 등록 안내**
  CI에서 release 서명을 하려면 나중에 GitHub repo settings → Secrets 에 아래를 추가해야 합니다 (Phase 6 때):
  - `KEYSTORE_BASE64` — `base64 release.keystore` 출력값
  - `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
  - `KAKAO_APP_KEY`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`

  Phase 0에서는 debug 빌드만 CI에서 돌림.

- [ ] **Step 4: 커밋 + push**
  ```bash
  cd ~/dev/moabook-app
  git add .github/
  git commit -m "feat(ci): add Identity Gate + flutter test + android debug build"
  ```
  GitHub remote 아직 없으면:
  ```bash
  # GitHub에서 새 repo 생성 후:
  git remote add origin https://github.com/<YOUR_USERNAME>/moabook-app.git
  git branch -M main
  git push -u origin main
  ```
  CI Actions 탭에서 워크플로 green 확인.

---

## Task 10: 최종 통합 확인

- [ ] **Step 1: 전체 identity 스크립트 최종 실행**
  ```bash
  cd ~/dev/moabook-app
  bash scripts/verify_identity.sh
  ```
  Expected: 전 항목 `✓`, exit 0

- [ ] **Step 2: flutter test 전체 pass**
  ```bash
  flutter test
  ```
  Expected: `All tests passed!`

- [ ] **Step 3: Android 실기기 or 에뮬레이터에서 확인**
  ```bash
  flutter run --dart-define-from-file=env/prod.json
  ```
  확인 항목:
  - 앱 아이콘 이름이 "모아북"으로 표시
  - 앱 정보 → 패키지명이 `project.side.ikdaman`

- [ ] **Step 4: iOS 시뮬레이터에서 확인**
  ```bash
  flutter run --dart-define-from-file=env/prod.json -d "iPhone 15"
  ```
  확인 항목:
  - 앱 이름 "모아북"
  - 설정 → 일반 → 앱에서 번들 ID `com.gogochang.Ikdaman` (Xcode Instruments로 확인 가능)

- [ ] **Step 5: screenshots/baseline 복사 (나중을 위해)**
  ```bash
  cp -r ~/dev/moabook/screenshots/baseline ~/dev/moabook-app/screenshots/baseline
  ```

- [ ] **Step 6: Phase 0 완료 커밋**
  ```bash
  cd ~/dev/moabook-app
  git add .
  git status  # key.properties, release.keystore, env/prod.json 이 staged 안 됨을 확인
  git commit -m "chore: Phase 0 complete — identity locked, env system, CI gate"
  ```

---

## Phase 0 Definition of Done 체크리스트

- [ ] `bash scripts/verify_identity.sh` → 전 항목 ✓
- [ ] `flutter test` → All passed
- [ ] `flutter build apk --debug` → 성공
- [ ] `flutter build ios --simulator` → Build Succeeded
- [ ] Android 실기기에서 앱 이름 "모아북", 패키지 `project.side.ikdaman` 확인
- [ ] GitHub Actions Identity Gate → 🟢 green
- [ ] `screenshots/baseline/` 에 15개 이상 PNG 존재
- [ ] `git log --oneline` 에 이 phase의 커밋 7개 이상 보임
- [ ] `release.keystore`, `android/key.properties`, `env/prod.json` 이 `git status` 에 untracked/ignored 상태 (절대 커밋 안 됨)

---

## 다음 단계

Phase 0 DoD 체크 완료 후 → `docs/superpowers/plans/2026-05-25-phase-1-infra.md` 작성 시작.
Phase 1 범위: 디자인 토큰(Theme/Typography/Color), go_router, Dio + 인터셉터, PixelShadowBox CustomPainter, flutter_svg 셋업, Riverpod 부트.
