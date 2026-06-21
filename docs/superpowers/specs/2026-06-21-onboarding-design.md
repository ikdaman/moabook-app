# 온보딩 화면 설계 (Onboarding)

작성일: 2026-06-21
대상: moabook-app (Flutter / go_router / Riverpod)
Figma: 채널 `h835ax4v`, 프레임 1~6 (`4848:3575` 외)

## 1. 목표

앱 첫 진입에 온보딩 시퀀스를 추가한다. 온보딩 마지막에 바로 홈으로
가지 않고 **로그인 화면**으로 보내 로그인을 먼저 끝내게 한다. 온보딩
중 사용자가 고른 책은 **보류**했다가 로그인 완료 후 실제로 등록한다.

핵심 연출:
- 온보딩 텍스트는 **콘솔 타자기** 스타일(글자 한 자씩 타이핑, 커서가 같이
  이동). 화면 전환 시 **백스페이스처럼 한 자씩 지워짐**.
- 마지막 화면 상단 박스에 **픽셀/도트 폭죽** 애니메이션(흰색, 투명 배경).
- 책 추가 팝업에는 타이핑 애니메이션 없음.

## 2. 플로우 & 라우팅

```
Splash ──(isLoggedIn?)──► yes ─► Home
                          └ no ─► Onboarding ─► Login ─► [보류책 저장] ─► Home
```

- 현재 `SplashScreen._navigate()`: `isLoggedIn ? Home : Login`
  → `isLoggedIn ? Home : Onboarding` 으로 변경.
- 온보딩 노출 시점: **지금은 매번**(디버그/테스트용). 나중에 "최초 1회"
  제한을 쉽게 켤 수 있도록 플래그 자리만 남긴다(아래 13. 향후 작업).
- 온보딩 종료(6번 "시작하기" 또는 Skip) → `context.go(Routes.login)`.
- `Routes.onboarding = '/onboarding'` 추가, `app_router.dart`에 GoRoute 추가.

## 3. 화면 구성

Figma 6프레임은 **논리적으로 4단계**다(3·4·5는 "검색 단계"의 상태 변화):

| 논리 step | Figma | 내용 | 타이핑 |
|---|---|---|---|
| `intro1` | 1 | "모아북" | O |
| `intro2` | 2 | 로고 "모 아 북" + 부제 | O |
| `search` | 3·4·5 | 프롬프트 + 검색창 → 결과 → 저장 팝업 | 프롬프트만 O, 팝업 X |
| `done` | 6 | 폭죽 박스 + 메시지 + "시작하기" | O |

`intro1 → intro2 → search` 는 끊김 없이 흐른다. `search`의 프롬프트는
한 번 타이핑된 뒤 결과/팝업 동안 그대로 유지된다. 저장 팝업에서 저장하면
프롬프트가 백스페이스로 지워지고 `done` 으로 전환된다.

### 공통 스타일 (Figma 추출)
- 배경: 네이비 `#010196` (`AppColors`에 `onboardingBackground` 추가)
- 온보딩 텍스트: `DungGeunMo`, 흰색 `#FFFFFF`
  - 타이틀 28/lh48, 본문 18/lh18, 검색 힌트 16 (`#D4D4D4`)
- 책 결과 아이템: `Wanted Sans` (제목 16 w600, 저자/출판사 14 w400, 흰색)
- 저장 팝업: 흰 배경, 다크 텍스트 `#333333`
- Skip 버튼: 우측 상단, 작은 흰색 글씨(작게), 전 step 공통

### step별 텍스트 (정확본)
- intro1: `모아북`
- intro2: 로고 `모 아 북` + 본문 `읽고 싶은 책을 모아두는\n나만의 공간 !`
- search 프롬프트: `요즘 읽고 싶다고 생각한\n책이 있으신가요?\n\n어떤 책인지 궁금해요.`
  - 검색창 힌트: `책 제목을 검색해주세요.`
- done: `BOOK SAVED !\n당신의 읽고 싶은 마음이\n기록됐어요.\n\n로그인하고 이곳에서\n읽고 싶은 책을 모아보세요.`
  - 버튼: `시작하기`

## 4. 타이핑 애니메이션 — `TypingText`

신규 위젯 `lib/features/onboarding/widget/typing_text.dart`.

- 전진: 글자 한 자씩 노출(`substring(0, i)`), 커서가 끝에서 같이 전진.
- 사라짐: 백스페이스처럼 한 자씩 삭제, 커서 후퇴.
- 커서: `_text` 끝에 붙는 `|`. 별도 타이머로 깜빡임(이동 중 solid,
  대기 중 blink).
- 가드: 각 `await` 후 `mounted && !_cancelled` 확인. `dispose()`에서
  `_cancelled = true` (Skip/이탈 시 setState 폭주 방지).

API(안):
```dart
TypingText(
  phrases: ['모아북'],          // 순서대로
  charInterval: Duration(ms: 60),
  eraseInterval: Duration(ms: 30),
  holdDuration: Duration(ms: 1000),
  onComplete: () {},           // 타이핑(또는 시퀀스) 끝 → 다음 step
)
```
화면 전환은 "현재 텍스트 erase → 다음 step 텍스트 type" 를 한 위젯
안에서 수행(커서 연속성 유지). 컨트롤러가 step 인덱스를 관리한다.

## 5. 폭죽 애니메이션 — `PixelFireworks` (구현·확정됨)

`lib/features/onboarding/widget/pixel_fireworks.dart` (이미 작성, 락).

- `CustomPainter` 파티클. 사각형 픽셀(`drawRect`, `isAntiAlias=false`),
  6px 그리드 스냅, fps 양자화(14fps) → 도트 게임 choppy 느낌.
- 흰색 전용 + 투명 배경. 방사형 streak(중심→바깥 선분, head 밝고 tail fade).
- burst: 로켓 상승 → 플래시 → 방사 → fade. 박스 영역(`clipRect`) 안에서만.
- 변주: 높이(apexY 0.20~0.68)·크기(reachFactor)·입자수·속도·대칭/산개 랜덤.
- 동시 표시 **최대 3발**, 연속 발 위치 최소 간격 0.3, 끝 15% 정적.
- 튜닝 노브: `cycle`(전체 길이) · `_explodeDur`(발 속도) · 동시수 cap.
- Figma 6번 박스 크기 268×150 위에 배치(원본은 lottie placeholder였음).

## 6. 저장 팝업 — 온보딩 전용 (신규)

Figma 5번 팝업은 기존 `showBookRegisterSheet`(내서점/히스토리 탭 + 취소/확인)와
다르다. 온보딩은 "읽고 싶은 책" 1종만 다루므로 **단순화된 신규 팝업**을 만든다.

`lib/features/onboarding/widget/onboarding_save_popup.dart`
- `PixelPopup` 쉘 재사용.
- 구성: 제목 `책 추가`, 책 제목(선택 책), `*읽고 싶은 책이에요.`,
  이유 입력(힌트 `왜 이 책을 읽고 싶으신가요?\n한 줄만 적어보세요.`, `0/400`),
  `SAVE` 버튼, `X` 닫기. 탭 없음, 날짜 없음.
- 반환: `String? reason` (입력한 이유, 비면 null).
- 타이핑 애니메이션 없음.

## 7. 책 검색/결과 — 기존 재사용

- 검색: `bookSearchProvider.search(query)` 재사용. 알라딘 API는 자체 Dio
  (인증 없음)라 **로그인 전 검색 OK**. 결과 선택은 `searchByIsbn` /
  `selectBook` 재사용.
- 단, 온보딩 검색 UI는 네이비 배경/온보딩 레이아웃에 맞춰 별도 위젯으로
  감싼다(기존 `SearchBookScreen` 통째 재사용 X — 배경/프롬프트 동거 때문).
  내부 결과 아이템 렌더는 기존 패턴을 따른다.

## 8. 보류책 — 인메모리 provider

`lib/features/onboarding/provider/pending_book_provider.dart`

```dart
class PendingBook {
  final BookItem book;
  final String? reason;
}
final pendingBookProvider = StateProvider<PendingBook?>((_) => null);
```

- 5번 저장 시: 실제 `saveBook` 호출하지 않고 `pendingBookProvider`에 보관.
- 저장 방식 = **인메모리**(소셜 로그인은 동일 프로세스라 유지됨). 앱 강제
  종료 시 유실되지만 온보딩 재진행으로 충분(매번 노출 상태).
- Skip 시: 보관 없이 그대로 로그인으로.

## 9. 보류책 소비 — Home 첫 진입

로그인/회원가입 둘 다 결국 `Home` 도착 → 소비 지점을 **Home 한 곳**으로 일원화.

- `HomeScreen` 첫 빌드 시 `pendingBookProvider` 확인:
  - 있으면 `bookSearchProvider.saveBook(book, reason)` 호출(이제 인증 토큰
    있음) → 성공 시 `pendingBookProvider = null` + 스낵바(`책을 저장했어요`)
    + 홈 새로고침(`saveBook` 내부에서 `homeProvider.load()` 수행).
  - 실패 시 provider 유지(다음 진입에 재시도) + 에러 스낵바.
- 중복 소비 방지: 소비 시작 즉시 provider를 비우거나 in-flight 플래그 사용.

## 10. Skip 버튼

- 위치: 우측 상단(SafeArea 안), 작은 흰색 글씨 `건너뛰기`.
- 모든 step 공통 노출.
- 동작: `pendingBookProvider` 비우고 `context.go(Routes.login)`.

## 11. 파일 구조

```
lib/features/onboarding/
  screen/onboarding_screen.dart        # step 컨트롤러 + 레이아웃
  widget/typing_text.dart              # 타자기 텍스트(전진/백스페이스/커서)
  widget/pixel_fireworks.dart          # 폭죽 (작성됨)
  widget/onboarding_save_popup.dart    # 저장 팝업(신규)
  provider/pending_book_provider.dart  # 보류책 상태
변경:
  lib/app/router/routes.dart           # onboarding 경로
  lib/app/router/app_router.dart       # GoRoute 추가
  lib/features/splash/screen/splash_screen.dart  # 미로그인 → onboarding
  lib/features/home/screen/home_screen.dart      # 보류책 소비
  lib/app/theme/app_colors.dart        # onboardingBackground(#010196)
```

## 12. 엣지 케이스

- Skip을 검색 도중/팝업 도중 눌러도 안전(타이핑 가드, provider 클리어).
- 검색 결과 없음: 기존 "검색 결과가 없습니다." 패턴 유지(직접 입력은 온보딩
  범위 밖 — 결과 선택만 다룸).
- 보류책 저장 실패(네트워크): provider 유지 + 다음 Home 진입 재시도.
- 회원가입 필요 분기(`LoginSignupRequired`): 회원가입 완료 후에도 Home에서
  보류책 소비됨(소비 지점이 Home이라 자동 커버).
- 타이핑 도중 화면 이탈: `_cancelled`로 루프 종료.

## 13. 테스트

- `TypingText`: 전진으로 전체 문자열 도달, 백스페이스로 빈 문자열,
  `onComplete` 호출. dispose 후 setState 없음.
- 온보딩 플로우: step 진행, Skip → login 라우팅.
- 보류책: 팝업 저장 → `pendingBookProvider` 채워짐 / Home 진입 시 소비 +
  클리어.
- `PixelFireworks`: 스모크(예외 없이 paint, 박스 밖 미출력은 clip로 보장).

## 14. 향후 작업 (범위 밖)

- 온보딩 "최초 1회" 제한: `secure_storage`에 `onboardingSeen` 플래그 →
  Splash 분기에서 `!seen && !loggedIn` 일 때만 온보딩. (지금은 매번)
- 보류책 영속화(앱 강제종료 생존)가 필요해지면 인메모리 → secure_storage.
- 데모 파일 `lib/fireworks_demo.dart` 는 구현 마무리 시 삭제.

## 15. 결정 로그

- 보류책: 인메모리 provider (A안). 영속(B)은 향후.
- 노출: 매번(디버그). 1회 제한은 플래그로 향후.
- Skip: 있음(우측 상단 작은 흰색).
- 진행: intro 자동 → search 사용자 입력 → 저장 → done → 로그인.
- 폭죽: 자작 CustomPainter 픽셀(흰색/투명/방사선/박스내/최대3발) — 확정.
- 저장 팝업: 온보딩 전용 단순 팝업(신규), 기존 register sheet와 분리.
