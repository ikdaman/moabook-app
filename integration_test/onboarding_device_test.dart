import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/app/theme/app_theme.dart';
import 'package:moabook/data/datasource/book_catalog_datasource.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/book_search/provider/book_search_provider.dart';
import 'package:moabook/features/onboarding/provider/pending_book_provider.dart';
import 'package:moabook/features/onboarding/screen/onboarding_screen.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

// Fixtures only: no account access, server writes or persistent preference changes.
final selectedBook = BookItem(
  title: previewBooks.first.title,
  author: previewBooks.first.author,
  publisher: previewBooks.first.publisher,
  cover: '',
  isbn: '',
  itemId: 1,
  link: '',
  description: '',
  pubDate: '',
);

class FixtureCatalog implements BookCatalogDataSource {
  @override
  Future<List<BookItem>> searchByTitle(
    String query, {
    int page = 1,
    bool byKeyword = false,
  }) async => [selectedBook];
  @override
  Future<List<BookItem>> searchByIsbn(String isbn) async => [selectedBook];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'tutorial selection, optional note, handoff and explicit first card record',
    (tester) async {
      // Real Android IMEs can overwrite injected editing state. Keep automated
      // text entry deterministic; keyboard-inset layouts are covered by widget tests.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [bookCatalogProvider.overrideWithValue(FixtureCatalog())],
      );
      final router = GoRouter(
        initialLocation: Routes.onboarding,
        routes: [
          GoRoute(
            path: Routes.onboarding,
            builder: (_, _) => const OnboardingScreen(),
          ),
          GoRoute(
            path: Routes.login,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('LOGIN_HANDOFF'))),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            builder: fixedAppTextScale,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('첫 책 고르기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '소년');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('책 검색'));
      for (
        var i = 0;
        i < 50 && find.text(selectedBook.title).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(selectedBook.title), findsWidgets);
      await tester.tap(find.text(selectedBook.title).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '마음에 남는 문장을 만나고 싶어서');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('이 책으로 시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('첫 책을 골랐어요.'), findsOneWidget);
      expect(container.read(pendingBookProvider)?.reason, '마음에 남는 문장을 만나고 싶어서');
      final start = find.text('로그인하고 서가 시작하기');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('LOGIN_HANDOFF'), findsOneWidget);
      // Account authentication is not simulated as a successful provider login.
      // Independently exercise the real card UI against its offline fixture journal.
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await tester.pumpWidget(
        const ReadingWorkspace(
          initialMood: Mood.a,
          initialScreen: 'card-empty',
        ),
      );
      await tester.pumpAndSettle();
      final firstRecord = find.text('첫 기록 남기기');
      await tester.ensureVisible(firstRecord);
      await tester.tap(firstRecord);
      await tester.pumpAndSettle();
      await tester.tap(find.text('자유 기록'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '책과 함께할 첫 순간을 남겼다.');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록 완료'));
      await tester.pumpAndSettle();
      final state = tester.state<ReadingWorkspaceState>(
        find.byType(ReadingWorkspace),
      );
      expect(state.screen, 'record-complete');
      expect(state.journal.records.single.memo, '책과 함께할 첫 순간을 남겼다.');
      await tester.tap(find.text('독서카드로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('책과 함께할 첫 순간을 남겼다.'), findsOneWidget);
      expect(find.text('기록 추가'), findsOneWidget);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'platform': defaultTargetPlatform.name,
        'tutorial_selection_note_handoff': true,
        'explicit_first_record': true,
        'fixture_only': true,
        'input': 'test_keyboard',
        'server_writes': 0,
      };
    },
  );
}
