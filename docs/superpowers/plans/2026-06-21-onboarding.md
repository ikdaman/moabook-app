# 온보딩 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱 첫 진입에 타자기 인트로 → 책 검색/보류 → 픽셀 폭죽 완료 화면으로 이어지는 온보딩을 추가하고, 끝나면 로그인으로 보내 로그인 후 보류책을 실제 등록한다.

**Architecture:** 신규 `lib/features/onboarding/` 모듈. step 인덱스를 가진 단일 `OnboardingScreen`이 인트로(타이핑)·검색·완료를 관리. 검색은 기존 `bookSearchProvider`(알라딘 무인증) 재사용. 고른 책은 인메모리 `pendingBookProvider`에 보류했다가 `HomeScreen` 첫 진입에서 소비. go_router에 `/onboarding` 추가, Splash가 미로그인 시 온보딩으로 분기.

**Tech Stack:** Flutter, flutter_riverpod, go_router, CustomPainter(폭죽), DungGeunMo/Wanted Sans 폰트.

## Global Constraints

- 배경색: `AppColors.primary` (`#FF010196`, 네이비) — 온보딩 전 화면.
- 온보딩 텍스트 폰트: `DungGeunMo`, 흰색 `AppColors.textWhite`.
- 온보딩 노출: **매번**(디버그). "최초 1회" 제한은 향후(범위 밖).
- 보류책 저장: **인메모리** `StateProvider`. 영속화 안 함.
- Skip: 우측 상단 작은 흰색 글씨, 전 step 공통, 누르면 보류책 비우고 로그인.
- 책 추가 팝업엔 타이핑 애니메이션 없음.
- 정확 copy (verbatim):
  - intro1: `모아북`
  - intro2 부제: `읽고 싶은 책을 모아두는\n나만의 공간 !`
  - search 프롬프트: `요즘 읽고 싶다고 생각한\n책이 있으신가요?\n\n어떤 책인지 궁금해요.`
  - 검색 힌트: `책 제목을 검색해주세요.`
  - done: `BOOK SAVED !\n당신의 읽고 싶은 마음이\n기록됐어요.\n\n로그인하고 이곳에서\n읽고 싶은 책을 모아보세요.`
  - done 버튼: `시작하기`
  - Skip 라벨: `건너뛰기`
- 폭죽 위젯 `lib/features/onboarding/widget/pixel_fireworks.dart` 는 이미 구현·확정됨(재작성 금지).

---

### Task 1: 보류책 모델 + provider

**Files:**
- Create: `lib/features/onboarding/provider/pending_book_provider.dart`
- Test: `test/features/onboarding/pending_book_provider_test.dart`

**Interfaces:**
- Consumes: `BookItem` (`lib/domain/model/book_item.dart`).
- Produces:
  - `class PendingBook { final BookItem book; final String? reason; const PendingBook({required this.book, this.reason}); }`
  - `final pendingBookProvider = StateProvider<PendingBook?>((ref) => null);`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/onboarding/pending_book_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/onboarding/provider/pending_book_provider.dart';

BookItem _book() => const BookItem(
      title: '소년이 온다', author: '한강', cover: '', publisher: '창비',
      isbn: '9788936434120', itemId: 1, link: '', description: '',
      pubDate: '2014-05-19', totalPage: 216,
    );

void main() {
  test('기본값은 null', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(pendingBookProvider), isNull);
  });

  test('보류책 저장/클리어', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(pendingBookProvider.notifier).state =
        PendingBook(book: _book(), reason: '읽고 싶어서');
    expect(c.read(pendingBookProvider)!.book.title, '소년이 온다');
    expect(c.read(pendingBookProvider)!.reason, '읽고 싶어서');
    c.read(pendingBookProvider.notifier).state = null;
    expect(c.read(pendingBookProvider), isNull);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/onboarding/pending_book_provider_test.dart`
Expected: FAIL — `pending_book_provider.dart` 없음(컴파일 에러).

- [ ] **Step 3: 구현**

```dart
// lib/features/onboarding/provider/pending_book_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/model/book_item.dart';

/// 온보딩에서 고른 책을 로그인 완료 전까지 임시 보관.
class PendingBook {
  final BookItem book;
  final String? reason;
  const PendingBook({required this.book, this.reason});
}

/// 인메모리 보류책. 로그인 후 Home 첫 진입에서 소비 후 null 로 클리어.
final pendingBookProvider = StateProvider<PendingBook?>((ref) => null);
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/pending_book_provider_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/onboarding/provider/pending_book_provider.dart test/features/onboarding/pending_book_provider_test.dart
git commit -m "feat(onboarding): 보류책 인메모리 provider 추가"
```

---

### Task 2: 타자기 텍스트 위젯 `TypingText`

**Files:**
- Create: `lib/features/onboarding/widget/typing_text.dart`
- Test: `test/features/onboarding/typing_text_test.dart`

**Interfaces:**
- Produces:
  ```dart
  TypingText({
    Key? key,
    required List<String> phrases,
    TextStyle? style,
    TextAlign textAlign = TextAlign.center,
    Duration charInterval = const Duration(milliseconds: 60),
    Duration eraseInterval = const Duration(milliseconds: 30),
    Duration holdDuration = const Duration(milliseconds: 1000),
    bool eraseAtEnd = false,
    VoidCallback? onComplete,
  })
  ```
  - 동작: `phrases`를 순서대로 타이핑. 각 문장 사이엔 `holdDuration` 후
    백스페이스로 지우고 다음 문장. 마지막 문장은 `eraseAtEnd`가 true면 지우고,
    아니면 유지. 전체 끝나면 `onComplete()`.
  - 커서 `|` 가 항상 텍스트 끝에 표시(깜빡임).

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/onboarding/typing_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/onboarding/widget/typing_text.dart';

void main() {
  testWidgets('한 글자씩 타이핑되고 완료 콜백 호출', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypingText(
          phrases: const ['모아북'],
          charInterval: const Duration(milliseconds: 10),
          holdDuration: const Duration(milliseconds: 10),
          onComplete: () => done = true,
        ),
      ),
    ));
    // 초기엔 아직 전체 안 나옴
    await tester.pump(const Duration(milliseconds: 15)); // 1글자
    expect(find.textContaining('모'), findsOneWidget);
    expect(find.textContaining('모아북'), findsNothing);
    // 충분히 진행하면 전체 + onComplete
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('모아북'), findsOneWidget);
    expect(done, isTrue);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  });

  testWidgets('dispose 후 setState 예외 없음', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypingText(
          phrases: const ['안녕하세요반갑습니다'],
          charInterval: const Duration(milliseconds: 30),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/onboarding/typing_text_test.dart`
Expected: FAIL — `typing_text.dart` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/onboarding/widget/typing_text.dart
import 'dart:async';
import 'package:flutter/material.dart';

class TypingText extends StatefulWidget {
  const TypingText({
    super.key,
    required this.phrases,
    this.style,
    this.textAlign = TextAlign.center,
    this.charInterval = const Duration(milliseconds: 60),
    this.eraseInterval = const Duration(milliseconds: 30),
    this.holdDuration = const Duration(milliseconds: 1000),
    this.eraseAtEnd = false,
    this.onComplete,
  });

  final List<String> phrases;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration charInterval;
  final Duration eraseInterval;
  final Duration holdDuration;
  final bool eraseAtEnd;
  final VoidCallback? onComplete;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _text = '';
  bool _cursorOn = true;
  bool _cancelled = false;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) setState(() => _cursorOn = !_cursorOn);
      },
    );
    _run();
  }

  Future<void> _run() async {
    for (var p = 0; p < widget.phrases.length; p++) {
      final phrase = widget.phrases[p];
      // 전진 타이핑
      for (var i = 1; i <= phrase.length; i++) {
        if (!mounted || _cancelled) return;
        setState(() => _text = phrase.substring(0, i));
        await Future.delayed(widget.charInterval);
      }
      if (!mounted || _cancelled) return;
      await Future.delayed(widget.holdDuration);
      final isLast = p == widget.phrases.length - 1;
      if (!isLast || widget.eraseAtEnd) {
        // 백스페이스 삭제
        for (var i = phrase.length - 1; i >= 0; i--) {
          if (!mounted || _cancelled) return;
          setState(() => _text = phrase.substring(0, i));
          await Future.delayed(widget.eraseInterval);
        }
      }
    }
    if (!mounted || _cancelled) return;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _cancelled = true;
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_text${_cursorOn ? '|' : ' '}',
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/typing_text_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/onboarding/widget/typing_text.dart test/features/onboarding/typing_text_test.dart
git commit -m "feat(onboarding): 타자기 텍스트 위젯(TypingText)"
```

---

### Task 3: 폭죽 위젯 스모크 테스트

**Files:**
- Modify: (없음 — `pixel_fireworks.dart` 는 구현 완료)
- Test: `test/features/onboarding/pixel_fireworks_test.dart`

**Interfaces:**
- Consumes: `PixelFireworks({Key? key, double pixelUnit, int fps, Duration cycle, int seed})`
  (`lib/features/onboarding/widget/pixel_fireworks.dart`, 이미 존재).

- [ ] **Step 1: 스모크 테스트 작성**

```dart
// test/features/onboarding/pixel_fireworks_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/onboarding/widget/pixel_fireworks.dart';

void main() {
  testWidgets('폭죽이 예외 없이 여러 프레임 렌더', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 268, height: 150, child: PixelFireworks()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    expect(find.byType(PixelFireworks), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행(통과해야 함)**

Run: `flutter test test/features/onboarding/pixel_fireworks_test.dart`
Expected: PASS (위젯 이미 구현됨)

- [ ] **Step 3: 커밋**

```bash
git add test/features/onboarding/pixel_fireworks_test.dart
git commit -m "test(onboarding): 폭죽 위젯 스모크 테스트"
```

---

### Task 4: 온보딩 저장 팝업 `OnboardingSavePopup`

**Files:**
- Create: `lib/features/onboarding/widget/onboarding_save_popup.dart`
- Test: `test/features/onboarding/onboarding_save_popup_test.dart`

**Interfaces:**
- Consumes: `PixelPopup({required VoidCallback onDismiss, required Widget child})`
  (`lib/shared/widgets/pixel_popup.dart`), `PixelShadowButton`
  (`lib/shared/widgets/pixel_shadow_box.dart`), `BookItem`,
  `AppColors`, `AppTypography`.
- Produces:
  - `Future<String?> showOnboardingSavePopup(BuildContext context, BookItem book)`
    → SAVE 누르면 입력 이유(빈 문자열이면 null), X/취소면 `null`(저장 안 함 구분은
    호출부에서 별도 처리 불필요 — 아래 Task 6 참고: SAVE 여부는 결과가 아닌
    "팝업이 SAVE로 닫혔는지"로 판단해야 하므로 결과를 `({bool saved, String? reason})`로 둔다).

  실제 시그니처(확정):
  ```dart
  class OnboardingSaveResult {
    final bool saved;
    final String? reason;
    const OnboardingSaveResult({required this.saved, this.reason});
  }
  Future<OnboardingSaveResult?> showOnboardingSavePopup(
      BuildContext context, BookItem book);
  ```
  - SAVE → `OnboardingSaveResult(saved: true, reason: ...)`
  - X/바깥 → `null`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/onboarding/onboarding_save_popup_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/onboarding/widget/onboarding_save_popup.dart';

const _book = BookItem(
  title: 'UX/UI 디자인 완벽 가이드', author: '저자', cover: '', publisher: '출판',
  isbn: '123', itemId: 1, link: '', description: '', pubDate: '2024', totalPage: 100,
);

void main() {
  testWidgets('SAVE 누르면 saved=true + 이유 반환', (tester) async {
    OnboardingSaveResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return Center(
            child: ElevatedButton(
              onPressed: () async =>
                  result = await showOnboardingSavePopup(ctx, _book),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('책 추가'), findsOneWidget);
    expect(find.text('UX/UI 디자인 완벽 가이드'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '읽고 싶어요');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.saved, isTrue);
    expect(result!.reason, '읽고 싶어요');
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/onboarding/onboarding_save_popup_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/onboarding/widget/onboarding_save_popup.dart
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../shared/widgets/pixel_popup.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';

class OnboardingSaveResult {
  final bool saved;
  final String? reason;
  const OnboardingSaveResult({required this.saved, this.reason});
}

Future<OnboardingSaveResult?> showOnboardingSavePopup(
  BuildContext context,
  BookItem book,
) {
  return showDialog<OnboardingSaveResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: SingleChildScrollView(child: _OnboardingSavePopup(book: book)),
    ),
  );
}

class _OnboardingSavePopup extends StatefulWidget {
  const _OnboardingSavePopup({required this.book});
  final BookItem book;

  @override
  State<_OnboardingSavePopup> createState() => _OnboardingSavePopupState();
}

class _OnboardingSavePopupState extends State<_OnboardingSavePopup> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PixelPopup(
      onDismiss: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('책 추가',
              style: AppTypography.dungGeunMoPopupTitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text(widget.book.title,
              style: AppTypography.wantedSansBody
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text('*읽고 싶은 책이에요.',
              style: AppTypography.dungGeunMoSubtitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 160,
            color: AppColors.backgroundWhite,
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                TextField(
                  controller: _reasonCtrl,
                  onChanged: (v) {
                    if (v.length > 400) {
                      _reasonCtrl.text = v.substring(0, 400);
                      _reasonCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: _reasonCtrl.text.length));
                    }
                    setState(() {});
                  },
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTypography.wantedSansBody
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '왜 이 책을 읽고 싶으신가요?\n한 줄만 적어보세요.',
                    hintStyle: AppTypography.wantedSansBody.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(bottom: 20),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text('${_reasonCtrl.text.length}/400',
                      style: AppTypography.wantedSansBodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.textPrimary.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: PixelShadowButton(
              onTap: () {
                final r = _reasonCtrl.text.trim();
                Navigator.of(context).pop(
                  OnboardingSaveResult(saved: true, reason: r.isEmpty ? null : r),
                );
              },
              backgroundColor: AppColors.backgroundGray,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text('SAVE',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/onboarding_save_popup_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/onboarding/widget/onboarding_save_popup.dart test/features/onboarding/onboarding_save_popup_test.dart
git commit -m "feat(onboarding): 온보딩 전용 책 저장 팝업"
```

---

### Task 5: 라우트 추가 + 온보딩 화면 스캐폴드

**Files:**
- Modify: `lib/app/router/routes.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `lib/features/onboarding/screen/onboarding_screen.dart` (스캐폴드만)
- Test: `test/features/onboarding/onboarding_route_test.dart`

**Interfaces:**
- Produces: `Routes.onboarding = '/onboarding'`, `OnboardingScreen` (ConsumerStatefulWidget).
- Consumes: `appRouter` 기존 구조.

- [ ] **Step 1: 실패 테스트 작성**

```dart
// test/features/onboarding/onboarding_route_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/router/routes.dart';

void main() {
  test('온보딩 경로 상수 존재', () {
    expect(Routes.onboarding, '/onboarding');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/onboarding/onboarding_route_test.dart`
Expected: FAIL — `Routes.onboarding` 없음.

- [ ] **Step 3: 라우트 상수 추가**

`lib/app/router/routes.dart` 의 `login` 줄 아래에 추가:
```dart
  static const onboarding      = '/onboarding';
```

- [ ] **Step 4: 온보딩 화면 스캐폴드 생성**

```dart
// lib/features/onboarding/screen/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(child: SizedBox.expand()),
    );
  }
}
```

- [ ] **Step 5: 라우터에 GoRoute 등록**

`lib/app/router/app_router.dart`:
import 추가 — 파일 상단 import 블록에:
```dart
import '../../features/onboarding/screen/onboarding_screen.dart';
```
`Routes.login` GoRoute 아래에 추가:
```dart
    GoRoute(
      path: Routes.onboarding,
      builder: (context, _) => const OnboardingScreen(),
    ),
```

- [ ] **Step 6: 테스트 통과 + 컴파일 확인**

Run: `flutter test test/features/onboarding/onboarding_route_test.dart && flutter analyze lib/app/router lib/features/onboarding`
Expected: PASS + analyze "No issues found!"

- [ ] **Step 7: 커밋**

```bash
git add lib/app/router/routes.dart lib/app/router/app_router.dart lib/features/onboarding/screen/onboarding_screen.dart test/features/onboarding/onboarding_route_test.dart
git commit -m "feat(onboarding): /onboarding 라우트 + 화면 스캐폴드"
```

---

### Task 6: 온보딩 화면 본문 (인트로 → 검색 → 완료)

**Files:**
- Modify: `lib/features/onboarding/screen/onboarding_screen.dart`
- Test: `test/features/onboarding/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `TypingText`, `PixelFireworks`, `showOnboardingSavePopup` /
  `OnboardingSaveResult`, `pendingBookProvider` / `PendingBook`,
  `bookSearchProvider` (`search`, `selectBook`, `searchByIsbn`, state
  `results`/`isLoading`/`selectedBook`), `BookItem`, `Routes`, `AppColors`,
  `AppTypography`.
- Produces: 완성된 `OnboardingScreenState` (step 진행 + Skip + 검색 + 저장).

**Step 모델 (private enum):** `_Step { intro1, intro2, search, done }`

- [ ] **Step 1: 위젯 테스트 작성 (Skip 라우팅 + 검색→저장→done 진행)**

```dart
// test/features/onboarding/onboarding_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/features/onboarding/screen/onboarding_screen.dart';

GoRouter _router() => GoRouter(
      initialLocation: Routes.onboarding,
      routes: [
        GoRoute(
            path: Routes.onboarding,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(
            path: Routes.login,
            builder: (_, __) =>
                const Scaffold(body: Text('LOGIN_SCREEN'))),
      ],
    );

void main() {
  testWidgets('건너뛰기 누르면 로그인으로 이동', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('건너뛰기'), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/onboarding/onboarding_screen_test.dart`
Expected: FAIL — 스캐폴드엔 '건너뛰기' 없음.

- [ ] **Step 3: 본문 구현**

```dart
// lib/features/onboarding/screen/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../features/book_search/provider/book_search_provider.dart';
import '../provider/pending_book_provider.dart';
import '../widget/onboarding_save_popup.dart';
import '../widget/pixel_fireworks.dart';
import '../widget/typing_text.dart';

enum _Step { intro1, intro2, search, done }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro1;
  final _queryCtrl = TextEditingController();

  static const _promptStyleTitle = TextStyle(
    fontFamily: 'DungGeunMo', color: AppColors.textWhite, fontSize: 28, height: 1.7);
  static const _promptStyleBody = TextStyle(
    fontFamily: 'DungGeunMo', color: AppColors.textWhite, fontSize: 18, height: 1.5);

  static const _searchPrompt =
      '요즘 읽고 싶다고 생각한\n책이 있으신가요?\n\n어떤 책인지 궁금해요.';
  static const _donePrompt =
      'BOOK SAVED !\n당신의 읽고 싶은 마음이\n기록됐어요.\n\n로그인하고 이곳에서\n읽고 싶은 책을 모아보세요.';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _goLogin() {
    ref.read(pendingBookProvider.notifier).state = null;
    context.go(Routes.login);
  }

  void _runSearch() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    ref.read(bookSearchProvider.notifier).search(q);
  }

  Future<void> _onBookTap(BookItem book) async {
    final notifier = ref.read(bookSearchProvider.notifier);
    BookItem selected = book;
    if (book.isbn.isNotEmpty) {
      final ok = await notifier.searchByIsbn(book.isbn);
      if (ok) {
        selected = ref.read(bookSearchProvider).selectedBook ?? book;
      } else {
        notifier.selectBook(book);
      }
    } else {
      notifier.selectBook(book);
    }
    if (!mounted) return;
    final result = await showOnboardingSavePopup(context, selected);
    if (result != null && result.saved) {
      ref.read(pendingBookProvider.notifier).state =
          PendingBook(book: selected, reason: result.reason);
      if (mounted) setState(() => _step = _Step.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildStep()),
            // Skip (우측 상단, 작은 흰색)
            Positioned(
              top: 8,
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _goLogin,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('건너뛰기',
                      style: AppTypography.dungGeunMoBodySmall.copyWith(
                          color: AppColors.textWhite, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.intro1:
        return Center(
          child: TypingText(
            phrases: const ['모아북'],
            style: _promptStyleTitle,
            eraseAtEnd: true,
            onComplete: () => setState(() => _step = _Step.intro2),
          ),
        );
      case _Step.intro2:
        return Center(
          child: TypingText(
            phrases: const ['읽고 싶은 책을 모아두는\n나만의 공간 !'],
            style: _promptStyleBody,
            eraseAtEnd: true,
            onComplete: () => setState(() => _step = _Step.search),
          ),
        );
      case _Step.search:
        return _SearchStep(
          promptStyle: _promptStyleBody,
          prompt: _searchPrompt,
          queryCtrl: _queryCtrl,
          onSubmit: _runSearch,
          onBookTap: _onBookTap,
        );
      case _Step.done:
        return _DoneStep(
          promptStyle: _promptStyleBody,
          prompt: _donePrompt,
          onStart: _goLogin,
        );
    }
  }
}

class _SearchStep extends ConsumerWidget {
  const _SearchStep({
    required this.promptStyle,
    required this.prompt,
    required this.queryCtrl,
    required this.onSubmit,
    required this.onBookTap,
  });
  final TextStyle promptStyle;
  final String prompt;
  final TextEditingController queryCtrl;
  final VoidCallback onSubmit;
  final Future<void> Function(BookItem) onBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookSearchProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          // 프롬프트는 1회 타이핑 후 유지(검색 step 동안 재타이핑 방지 위해
          // key 고정).
          TypingText(
            key: const ValueKey('search-prompt'),
            phrases: [prompt],
            style: promptStyle,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            color: AppColors.backgroundWhite,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: queryCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSubmit(),
                    style: AppTypography.dungGeunMoBody
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '책 제목을 검색해주세요.',
                      hintStyle: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textHint),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSubmit,
                  child: const Icon(Icons.search, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: state.results.length,
                    itemBuilder: (_, i) {
                      final b = state.results[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onBookTap(b),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title,
                                  style: AppTypography.wantedSansBookTitle
                                      .copyWith(color: AppColors.textWhite),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${b.author}  ${b.publisher}',
                                  style: AppTypography.wantedSansBodySmall
                                      .copyWith(color: AppColors.textWhite),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.promptStyle,
    required this.prompt,
    required this.onStart,
  });
  final TextStyle promptStyle;
  final String prompt;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const SizedBox(width: 268, height: 150, child: PixelFireworks()),
          const SizedBox(height: 24),
          TypingText(
            phrases: [prompt],
            style: promptStyle,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: Container(
                width: double.infinity,
                height: 48,
                color: AppColors.backgroundGray,
                alignment: Alignment.center,
                child: Text('시작하기',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

> 참고: `AppTypography.dungGeunMoBodySmall` 가 없으면 `dungGeunMoBody` 사용.
> 구현 전 `lib/app/theme/app_typography.dart`에서 존재하는 스타일명을 확인하고
> 맞춰 쓸 것(예: `dungGeunMoBody`, `dungGeunMoSubtitle`, `dungGeunMoPopupTitle`,
> `wantedSansBody`, `wantedSansBodySmall`, `wantedSansBookTitle`).

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/onboarding_screen_test.dart`
Expected: PASS

- [ ] **Step 5: 전체 analyze**

Run: `flutter analyze lib/features/onboarding`
Expected: No issues found!

- [ ] **Step 6: 커밋**

```bash
git add lib/features/onboarding/screen/onboarding_screen.dart test/features/onboarding/onboarding_screen_test.dart
git commit -m "feat(onboarding): 인트로/검색/완료 화면 본문"
```

---

### Task 7: Splash → 미로그인 시 온보딩 분기

**Files:**
- Modify: `lib/features/splash/screen/splash_screen.dart:22-26`
- Test: `test/features/onboarding/splash_redirect_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider.isLoggedIn()`, `Routes.onboarding`, `Routes.home`.

- [ ] **Step 1: 테스트 작성 (미로그인 → 온보딩)**

```dart
// test/features/onboarding/splash_redirect_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/splash/screen/splash_screen.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<bool> isLoggedIn() async => false;
  // 나머지 멤버는 noSuchMethod 로 처리(테스트 미사용).
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('미로그인 시 온보딩으로 이동', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.splash,
      routes: [
        GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: Routes.onboarding,
            builder: (_, __) => const Scaffold(body: Text('ONBOARDING'))),
        GoRoute(
            path: Routes.home,
            builder: (_, __) => const Scaffold(body: Text('HOME'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ONBOARDING'), findsOneWidget);
  });
}
```

> `AuthRepository` 의 실제 인터페이스/`authRepositoryProvider` 정의를
> `lib/features/auth/provider/auth_provider.dart` 에서 먼저 확인하고
> Fake/override 방식을 거기에 맞춘다. override가 어려우면 이 테스트는
> 생략하고 Step 3의 수동 검증으로 대체 가능(분기 1줄 변경이라 위험 낮음).

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/onboarding/splash_redirect_test.dart`
Expected: FAIL — 현재 미로그인 시 `Routes.login` 으로 감.

- [ ] **Step 3: 분기 변경**

`lib/features/splash/screen/splash_screen.dart` 의 `_navigate()`:
```dart
    context.go(isLoggedIn ? Routes.home : Routes.onboarding);
```
(기존 `Routes.login` → `Routes.onboarding`)

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/splash_redirect_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/features/splash/screen/splash_screen.dart test/features/onboarding/splash_redirect_test.dart
git commit -m "feat(onboarding): 미로그인 진입 시 온보딩으로 분기"
```

---

### Task 8: Home 첫 진입 시 보류책 소비

**Files:**
- Modify: `lib/features/home/screen/home_screen.dart` (`initState` + 신규 메서드)
- Test: `test/features/onboarding/pending_consume_test.dart`

**Interfaces:**
- Consumes: `pendingBookProvider` / `PendingBook`, `bookSearchProvider.saveBook(book, reason)`.
- 동작: Home 첫 빌드 후 `pendingBookProvider` 있으면 `saveBook` 호출 →
  성공 시 provider null + 스낵바. 중복 방지 플래그.

- [ ] **Step 1: 테스트 작성 (보류책 있으면 saveBook 호출 + 클리어)**

```dart
// test/features/onboarding/pending_consume_test.dart
//
// saveBook 는 네트워크 호출이므로, BookSearchNotifier 를 가짜로 교체해
// 호출 여부만 검증한다. bookSearchProvider override 로 주입.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/book_search/provider/book_search_provider.dart';
import 'package:moabook/features/onboarding/provider/pending_book_provider.dart';

// 실제 소비 로직을 순수 함수로 분리해 테스트한다(아래 Step 3 참고).
import 'package:moabook/features/home/screen/pending_book_consumer.dart';

class _FakeSearch implements PendingSaver {
  BookItem? savedBook;
  String? savedReason;
  @override
  Future<bool> saveBook(
      {required BookItem book, String? reason, String? startedDate, String? finishedDate}) async {
    savedBook = book;
    savedReason = reason;
    return true;
  }
}

const _book = BookItem(
  title: '소년이 온다', author: '한강', cover: '', publisher: '창비',
  isbn: '1', itemId: 1, link: '', description: '', pubDate: '2014', totalPage: 216,
);

void main() {
  test('보류책 있으면 저장 후 클리어', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(pendingBookProvider.notifier).state =
        const PendingBook(book: _book, reason: '읽고싶음');
    final saver = _FakeSearch();
    final ok = await consumePendingBook(
      pending: c.read(pendingBookProvider),
      saver: saver,
    );
    expect(ok, isTrue);
    expect(saver.savedBook!.title, '소년이 온다');
    expect(saver.savedReason, '읽고싶음');
  });

  test('보류책 없으면 아무것도 안 함', () async {
    final saver = _FakeSearch();
    final ok = await consumePendingBook(pending: null, saver: saver);
    expect(ok, isFalse);
    expect(saver.savedBook, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/onboarding/pending_consume_test.dart`
Expected: FAIL — `pending_book_consumer.dart` 없음.

- [ ] **Step 3: 소비 헬퍼 생성 (순수 로직 분리)**

```dart
// lib/features/home/screen/pending_book_consumer.dart
import '../../../domain/model/book_item.dart';
import '../../onboarding/provider/pending_book_provider.dart';

/// saveBook 만 추상화해 테스트 가능하게 한 인터페이스.
/// BookSearchNotifier 가 이를 만족한다(saveBook 시그니처 동일).
abstract class PendingSaver {
  Future<bool> saveBook({
    required BookItem book,
    String? reason,
    String? startedDate,
    String? finishedDate,
  });
}

/// 보류책이 있으면 저장하고 성공 여부 반환. 없으면 false.
Future<bool> consumePendingBook({
  required PendingBook? pending,
  required PendingSaver saver,
}) async {
  if (pending == null) return false;
  return saver.saveBook(book: pending.book, reason: pending.reason);
}
```

- [ ] **Step 4: `BookSearchNotifier` 가 `PendingSaver` 를 구현하도록 선언 추가**

`lib/features/book_search/provider/book_search_provider.dart`:
import 추가:
```dart
import '../../home/screen/pending_book_consumer.dart';
```
클래스 선언 변경:
```dart
class BookSearchNotifier extends Notifier<BookSearchState>
    implements PendingSaver {
```
(기존 `saveBook` 시그니처가 이미 `PendingSaver` 와 일치하므로 추가 구현 불필요.)

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/features/onboarding/pending_consume_test.dart`
Expected: PASS

- [ ] **Step 6: HomeScreen 에서 소비 호출**

`lib/features/home/screen/home_screen.dart`:
import 추가:
```dart
import '../../onboarding/provider/pending_book_provider.dart';
import 'pending_book_consumer.dart';
```
`_HomeScreenState` 에 플래그 + initState 호출 추가:
```dart
  bool _pendingConsumed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  Future<void> _consumePending() async {
    if (_pendingConsumed) return;
    final pending = ref.read(pendingBookProvider);
    if (pending == null) return;
    _pendingConsumed = true;
    final ok = await consumePendingBook(
      pending: pending,
      saver: ref.read(bookSearchProvider.notifier),
    );
    if (!mounted) return;
    if (ok) {
      ref.read(pendingBookProvider.notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('책을 저장했어요')),
      );
    } else {
      _pendingConsumed = false; // 실패 시 다음 진입 재시도
    }
  }
```
import 추가: `import '../../book_search/provider/book_search_provider.dart';`
(이미 있으면 생략).

- [ ] **Step 7: analyze + 전체 테스트**

Run: `flutter analyze lib/features/home lib/features/book_search && flutter test test/features/onboarding`
Expected: No issues found! + 모든 테스트 PASS

- [ ] **Step 8: 커밋**

```bash
git add lib/features/home/screen/home_screen.dart lib/features/home/screen/pending_book_consumer.dart lib/features/book_search/provider/book_search_provider.dart test/features/onboarding/pending_consume_test.dart
git commit -m "feat(onboarding): 로그인 후 Home 첫 진입에서 보류책 저장"
```

---

### Task 9: 정리 (데모 파일 + figma 설정)

**Files:**
- Delete: `lib/fireworks_demo.dart`

- [ ] **Step 1: 데모 파일 삭제**

```bash
git rm lib/fireworks_demo.dart
```

- [ ] **Step 2: 전체 빌드/분석/테스트 최종 확인**

Run: `flutter analyze && flutter test`
Expected: No issues found! + 전체 PASS

- [ ] **Step 3: 실기기 수동 검증 (사용자)**

Run: `flutter run -d <device> -t lib/main.dart`
확인: 앱 실행 → (로그아웃 상태) 온보딩 인트로 타이핑 → 검색(예: "소년")
→ 결과 탭 → 저장 팝업 SAVE → 폭죽 + "시작하기" → 로그인 → 로그인 완료 →
Home에서 "책을 저장했어요" 스낵바 + 보류책 등록 확인.

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "chore(onboarding): 폭죽 데모 파일 제거"
```

> 참고: `~/.claude.json` 의 moabook-app figma MCP 설정은 개발 편의용으로
> 둔 것이라 코드와 무관. 유지/제거는 사용자 판단(커밋 대상 아님).

---

## 자체 검토 결과

- **Spec 커버리지:** 라우팅(T5,T7) · 4 step/타이핑(T2,T6) · 폭죽(T3, 기구현)
  · 저장 팝업(T4) · 검색 재사용(T6) · 보류책 provider(T1)/소비(T8) ·
  Skip(T6) · 엣지(가드 T2, 실패 재시도 T8) · 테스트(각 Task) — 전부 매핑됨.
- **플레이스홀더:** 없음(코드 전량 기재). 단 T6/T7은 기존 타이포그래피 스타일명·
  AuthRepository 인터페이스를 구현 직전 확인하라는 주의만 명시.
- **타입 일관성:** `PendingBook{book,reason}`, `OnboardingSaveResult{saved,reason}`,
  `PendingSaver.saveBook(...)` 가 T1·T4·T8에서 일관. `bookSearchProvider` API
  (`search`/`selectBook`/`searchByIsbn`/`saveBook`/state)는 기존 코드와 일치.
```
