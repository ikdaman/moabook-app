// test/features/onboarding/onboarding_handoff_test.dart
//
// 핸드오프(handoff) 동작 검증:
//  - Skip(건너뛰기)은 보류책을 버린다(pendingBookProvider = null).
//  - 시작하기는 의도적으로 보류책을 클리어하지 않는다. 이는 _skipToLogin /
//    _startToLogin 으로 메서드를 분리해 보장한다(C1 버그픽스). 시작하기 →
//    로그인 → Home 까지 보류책이 살아남아 consumePendingBook 에서 소비된다.
//    시작하기의 풀 UI e2e(검색→저장→done→시작하기)는 TypingText/검색 네트워크
//    의존 때문에 수동 검증으로 남긴다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/home/screen/pending_book_consumer.dart';
import 'package:moabook/features/onboarding/provider/pending_book_provider.dart';
import 'package:moabook/features/onboarding/screen/onboarding_screen.dart';

const _book = BookItem(
  title: '테스트 책',
  author: '저자',
  cover: '',
  publisher: '출판사',
  isbn: '9781234567890',
  itemId: 1,
  link: '',
  description: '',
  pubDate: '2024-01-01',
);

GoRouter _router() => GoRouter(
      initialLocation: Routes.onboarding,
      routes: [
        GoRoute(
            path: Routes.onboarding,
            builder: (_, _) => const OnboardingScreen()),
        GoRoute(
            path: Routes.login,
            builder: (_, _) => const Scaffold(body: Text('LOGIN'))),
      ],
    );

/// consumePendingBook 검증용 가짜 saver. saveBook 호출을 기록한다.
class _FakePendingSaver implements PendingSaver {
  BookItem? savedBook;
  String? savedReason;
  bool result;
  _FakePendingSaver({this.result = true});

  @override
  Future<bool> saveBook({
    required BookItem book,
    String? reason,
    String? startedDate,
    String? finishedDate,
  }) async {
    savedBook = book;
    savedReason = reason;
    return result;
  }
}

void main() {
  testWidgets('건너뛰기는 보류책을 클리어하고 로그인으로 이동', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 보류책 사전 주입.
    container.read(pendingBookProvider.notifier).state =
        const PendingBook(book: _book, reason: '읽고싶어서');

    final router = _router();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    // Skip 버튼은 모든 step 에서 도달 가능(우측 상단 고정).
    expect(find.text('건너뛰기'), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    // 라우터 전환 + 남은 TypingText 타이머 소진.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // (a) 라우터가 /login 으로 이동.
    expect(find.text('LOGIN'), findsOneWidget);
    // (b) Skip 은 보류책을 클리어 → null.
    expect(container.read(pendingBookProvider), isNull);
  });

  test('보류책이 있으면 consumePendingBook 이 저장한다', () async {
    final saver = _FakePendingSaver();
    const pending = PendingBook(book: _book, reason: '읽고싶어서');

    final ok = await consumePendingBook(pending: pending, saver: saver);

    expect(ok, isTrue);
    expect(saver.savedBook, same(_book));
    expect(saver.savedReason, '읽고싶어서');
  });

  test('보류책이 없으면 consumePendingBook 은 저장하지 않는다', () async {
    final saver = _FakePendingSaver();

    final ok = await consumePendingBook(pending: null, saver: saver);

    expect(ok, isFalse);
    expect(saver.savedBook, isNull);
  });
}
