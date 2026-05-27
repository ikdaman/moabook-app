# iOS Widget Extension — Xcode 셋업

Swift 소스만으로는 위젯이 빌드되지 않는다. Xcode 에서 Widget Extension target 을 만들고 다음 파일들을 멤버로 추가해야 한다.

## 1. Widget Extension target 생성

1. Xcode 에서 `ios/Runner.xcworkspace` 열기
2. Runner project → File → New → Target → **Widget Extension**
3. Product Name: `MoabookWidget`
4. Bundle Identifier: `com.Ikdaman.MoabookWidget`
5. **Include Configuration Intent: OFF** (StaticConfiguration 사용)
6. Activate scheme 묻는 dialog: **Cancel** (Runner scheme 만 사용)

## 2. 자동 생성 파일 제거 + 우리 파일 추가

Xcode 가 자동 생성한 `MoabookWidget.swift`, `Info.plist` 등은 **모두 삭제** (Remove References, 파일은 실제 삭제 OK).

Project Navigator 에서 `MoabookWidget` 그룹 우클릭 → Add Files to "Runner"... → `ios/MoabookWidget/` 폴더의 다음 파일들 선택:

- `MoabookWidgetBundle.swift`
- `MoabookWidget.swift`
- `WidgetUiBook.swift`
- `WidgetTheme.swift`
- `DateLabel.swift`
- `Info.plist`
- `MoabookWidget.entitlements`

"Add to targets" 에서 **MoabookWidget 만 체크**, Runner 는 체크 해제.

## 3. Build Settings (MoabookWidget target)

- **iOS Deployment Target**: 16.0 (containerBackground 사용)
- **Info.plist File**: `MoabookWidget/Info.plist`
- **Code Signing Entitlements**: `MoabookWidget/MoabookWidget.entitlements`

## 4. App Group capability

### Apple Developer Portal

1. https://developer.apple.com/account → Identifiers
2. App Groups → `+` → `group.shop.moabook` 등록
3. Bundle ID `com.Ikdaman` 편집 → Capabilities → **App Groups** 체크 → `group.shop.moabook` 선택
4. Bundle ID `com.Ikdaman.MoabookWidget` 추가 (없다면) → 동일하게 App Groups 활성화

### Xcode

1. Runner target → Signing & Capabilities → `+` → **App Groups** → `group.shop.moabook` 체크
2. MoabookWidget target → Signing & Capabilities → `+` → **App Groups** → `group.shop.moabook` 체크
3. `Runner.entitlements` / `MoabookWidget.entitlements` 가 자동으로 capability 추가 반영하는지 확인

## 5. Provisioning Profile 재발급

iOS 인증서/프로비저닝은 fastlane match 로 관리 중이므로:

```bash
cd ~/dev/moabook-app/ios
export APP_STORE_KEY_ID=35SHWLN842
export APP_STORE_ISSUER_ID=e7624601-1e53-41bd-b54d-7bf952728abd
export APP_STORE_KEY_PATH=~/dev/korean_learning/ios/fastlane/AuthKey_35SHWLN842.p8
export MATCH_PASSWORD="<설정한 값>"

# 기존 cert/profile nuke 후 재생성
bundle exec fastlane match nuke distribution --skip_confirmation
bundle exec fastlane match nuke development --skip_confirmation
bundle exec fastlane sync_certs
```

## 6. 검증

```bash
flutter build ios --release --no-codesign
```

빌드 성공하면 끝. 실기기에서 위젯 추가해 "모아북" 위젯 S/M/L 확인.

---

## 데이터 흐름 요약

1. Flutter `WidgetPublisher.publish(books)` 호출 시 `home_widget` 플러그인이
   - iOS: `UserDefaults(suiteName: "group.shop.moabook")` 에 `recent_store_books_json` key 로 JSON 저장
   - `WidgetCenter.shared.reloadAllTimelines()` 호출
2. WidgetKit 이 `MoabookProvider.getTimeline()` 재호출 → `WidgetCache.read()` 가 UserDefaults 에서 JSON 읽기
3. 사용자가 위젯 탭 → `widgetURL` (`moabookwidget://book?id=X`) 으로 앱 deep link 진입
4. Flutter `WidgetNavigator.listen()` 이 `HomeWidget.widgetClicked` Stream 으로 수신 → `appRouter.go(Routes.bookInfo(id))`
