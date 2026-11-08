import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/data/datasource/book_catalog_datasource.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/book_search/provider/book_search_provider.dart';
import 'package:moabook/features/onboarding/onboarding_prefs.dart';
import 'package:moabook/features/onboarding/provider/pending_book_provider.dart';
import 'package:moabook/features/onboarding/screen/onboarding_screen.dart';

const book = BookItem(
  title: '우리가 빛의 속도로 갈 수 없다면',
  author: '김초엽',
  publisher: '허블',
  cover: '',
  isbn: '',
  itemId: 74261416,
  link: '',
  description: '',
  pubDate: '2019',
);

class Catalog implements BookCatalogDataSource {
  bool fail = false;
  @override
  Future<List<BookItem>> searchByTitle(
    String query, {
    int page = 1,
    bool byKeyword = false,
  }) async {
    if (fail) throw StateError('offline');
    return query == '없는 책' ? [] : [book];
  }

  @override
  Future<List<BookItem>> searchByIsbn(String isbn) async => [book];
}

void main() {
  Future<ProviderContainer> mount(WidgetTester tester, Catalog catalog) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [bookCatalogProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: Routes.onboarding,
      routes: [
        GoRoute(
          path: Routes.onboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('첫 책 고르기'));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.tap(find.byTooltip('책 검색'));
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selected book and optional reason survive the complete onboarding-to-login handoff',
    (tester) async {
      final container = await mount(tester, Catalog());
      await search(tester, '김초엽');
      await tester.tap(find.text(book.title).last);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      final memo = find.byType(TextField).last;
      await tester.ensureVisible(memo);
      await tester.enterText(memo, '다른 세계를 상상해보고 싶어서');
      await tester.pump();
      expect(find.text('이 책으로 시작하기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('이 책으로 시작하기'));
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('첫 책을 골랐어요.'), findsOneWidget);
      expect(find.textContaining('BOOK SAVED'), findsNothing);
      expect(container.read(pendingBookProvider)?.reason, '다른 세계를 상상해보고 싶어서');
      final action = find.text('로그인하고 서가 시작하기');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(container.read(pendingBookProvider)?.book.itemId, book.itemId);
      expect(
        (await SharedPreferences.getInstance()).getBool(kOnboardingSeenKey),
        isTrue,
      );
    },
  );

  testWidgets(
    'search stays usable with keyboard and retries errors without losing the query',
    (tester) async {
      final catalog = Catalog()..fail = true;
      await mount(tester, catalog);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await search(tester, '김초엽');
      expect(find.text('연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      catalog.fail = false;
      await tester.ensureVisible(find.text('다시 찾기'));
      await tester.tap(find.text('다시 찾기'));
      await tester.pumpAndSettle();
      expect(find.text(book.title), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
