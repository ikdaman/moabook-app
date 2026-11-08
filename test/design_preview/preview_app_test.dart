import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/design_preview/design_system.dart';
import 'package:moabook/design_preview/preview_app.dart';
import 'package:moabook/design_preview/sample_data.dart';

void main() {
  testWidgets('all design screens fit iPhone and narrow widths in both moods', (
    tester,
  ) async {
    for (final size in [const Size(402, 874), const Size(320, 740)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      for (final mood in Mood.values) {
        for (final screen in previewScreens.keys) {
          await tester.pumpWidget(
            DesignPreviewApp(
              key: UniqueKey(),
              initialMood: mood,
              initialScreen: screen,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${mood.name}/$screen at $size',
          );
        }
      }
    }
    addTearDown(tester.view.reset);
  });

  testWidgets(
    'collection title opens index and choosing a collection returns to shelf',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const DesignPreviewApp(initialScreen: 'collection'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-picker')));
      await tester.pumpAndSettle();
      expect(find.text('나의 컬렉션'), findsOneWidget);
      await tester.tap(find.text('새드엔딩'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-picker')), findsOneWidget);
      expect(find.text('새드엔딩'), findsOneWidget);
    },
  );

  testWidgets('collection editing exposes the save action', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const DesignPreviewApp(initialScreen: 'collection-edit'),
    );
    await tester.pumpAndSettle();
    final save = find.text('편집 완료');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-picker')), findsOneWidget);
  });

  testWidgets('book saving leaves status and dates to the first record', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DesignPreviewApp(initialScreen: 'save-wish'));
    await tester.pumpAndSettle();
    expect(find.text('읽고 싶은 이유 · 선택'), findsOneWidget);
    expect(find.text('읽고 있는 책'), findsNothing);
    expect(find.text('읽기 시작한 날'), findsNothing);
    expect(find.text('다 읽은 날'), findsNothing);
    expect(find.text('저장한 뒤 독서카드에서 첫 기록을 남겨보세요.'), findsOneWidget);
  });

  testWidgets('card tap and swipe flip without trapping back navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    for (final mood in Mood.values) {
      await tester.pumpWidget(
        DesignPreviewApp(
          key: UniqueKey(),
          initialMood: mood,
          initialScreen: 'card-front',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('카드 뒤의 기록 보기'), findsNothing);
      await tester.tap(find.text(previewBooks.first.title));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-back-surface')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('card-back-surface')),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-front-surface')), findsOneWidget);
      await tester.tap(find.text('추가하기'));
      await tester.pumpAndSettle();
      expect(find.text('순간 기록'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('닫기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('서가로 돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('서가'), findsOneWidget);
    }
  });

  testWidgets(
    'shelf has three visible rows and swipes through all sample pages',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final size in [const Size(402, 874), const Size(320, 740)]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        for (final mood in Mood.values) {
          await tester.pumpWidget(
            DesignPreviewApp(key: UniqueKey(), initialMood: mood),
          );
          await tester.pumpAndSettle();
          expect(find.text('90권'), findsOneWidget);
          expect(find.text('책 추가'), findsOneWidget);
          for (var row = 0; row < 3; row++) {
            final rectangle = tester.getRect(
              find.byKey(ValueKey('shelf-0-row-$row')),
            );
            expect(
              rectangle.bottom,
              lessThan(
                tester
                    .getRect(find.byKey(const Key('shelf-page-indicator')))
                    .top,
              ),
            );
            expect(rectangle.height, greaterThan(80));
          }
          String indicator() => tester
              .widget<Text>(find.byKey(const Key('shelf-page-indicator')))
              .data!;
          final pages = int.parse(indicator().split('/').last.trim());
          expect(pages, greaterThan(1));
          for (var page = 2; page <= pages; page++) {
            await tester.drag(
              find.byKey(const Key('shelf-pager')),
              Offset(-size.width * .8, 0),
            );
            await tester.pumpAndSettle();
            expect(indicator(), '$page / $pages');
          }
          await tester.drag(
            find.byKey(const Key('shelf-pager')),
            Offset(-size.width * .8, 0),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('collection-pager')), findsOneWidget);
          await tester.drag(
            find.byKey(const Key('collection-pager')),
            Offset(size.width * .8, 0),
          );
          await tester.pumpAndSettle();
          expect(indicator(), '$pages / $pages');
          final last = shelfPreviewBooks.last;
          await tester.tap(find.byKey(ValueKey('spine-${last.id}')));
          await tester.pumpAndSettle();
          expect(find.text(last.title), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.tap(find.bySemanticsLabel('서가로 돌아가기'));
          await tester.pumpAndSettle();
          expect(indicator(), '$pages / $pages');
          for (var page = pages - 1; page >= 1; page--) {
            await tester.drag(
              find.byKey(const Key('shelf-pager')),
              Offset(size.width * .8, 0),
            );
            await tester.pumpAndSettle();
            expect(indicator(), '$page / $pages');
          }
          await tester.tap(find.bySemanticsLabel('책 추가'));
          await tester.pumpAndSettle();
          expect(find.text('책 제목으로 검색'), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'shelf boundaries slide between the last shelf and first collection',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const DesignPreviewApp());
      await tester.pumpAndSettle();
      final state = tester.state<DesignPreviewState>(
        find.byType(DesignPreview),
      );
      final last = state.shelfPageCount - 1;
      state.shelfPages.jumpToPage(last);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('shelf-pager')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(state.screen, 'collection');
      expect(state.collectionPage, 0);
      // Moving within the collection pager must still work normally.
      await tester.drag(
        find.byKey(const Key('collection-pager')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(state.screen, 'collection');
      expect(state.collectionPage, 1);
      await tester.drag(
        find.byKey(const Key('collection-pager')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(state.screen, 'collection');
      expect(state.collectionPage, 0);
      await tester.drag(
        find.byKey(const Key('collection-pager')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(state.screen, 'shelf');
      expect(state.shelfPage, last);
      expect(state.shelfPages.page, last.toDouble());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings remains in the same top-right position on both shelves',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      for (final mood in Mood.values) {
        Rect? shelfSettings;
        for (final screen in ['shelf', 'collection']) {
          await tester.pumpWidget(
            DesignPreviewApp(
              key: UniqueKey(),
              initialMood: mood,
              initialScreen: screen,
            ),
          );
          await tester.pumpAndSettle();
          final settings = find.bySemanticsLabel('시안 설정');
          final rectangle = tester.getRect(settings);
          if (shelfSettings == null) {
            shelfSettings = rectangle;
          } else {
            expect(rectangle, shelfSettings);
          }
          await tester.tap(settings);
          await tester.pumpAndSettle();
          expect(find.text('디자인 시안'), findsOneWidget);
        }
      }
    },
  );
  testWidgets(
    'topic shelves swipe to creation and tab entry resets to first collection',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      for (final mood in Mood.values) {
        await tester.pumpWidget(
          DesignPreviewApp(
            key: UniqueKey(),
            initialMood: mood,
            initialScreen: 'collection',
          ),
        );
        await tester.pumpAndSettle();
        String indicator() => tester
            .widget<Text>(find.byKey(const Key('collection-page-indicator')))
            .data!;
        expect(indicator(), '1 / 7');
        expect(find.text('저장 이유 없음'), findsNothing);
        for (var page = 2; page <= 7; page++) {
          await tester.drag(
            find.byKey(const Key('collection-pager')),
            const Offset(-320, 0),
          );
          await tester.pumpAndSettle();
          expect(indicator(), '$page / 7');
        }
        expect(find.text('새 컬렉션 만들기'), findsNWidgets(2));
        await tester.drag(
          find.byKey(const Key('collection-pager')),
          const Offset(-320, 0),
        );
        await tester.pumpAndSettle();
        expect(indicator(), '7 / 7');
        await tester.tap(find.text('기본 서가'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('shelf-page-indicator')), findsOneWidget);
        await tester.tap(find.text('주제 서가'));
        await tester.pumpAndSettle();
        expect(indicator(), '1 / 7');
        await tester.tap(find.byKey(const Key('collection-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('새드엔딩'));
        await tester.pumpAndSettle();
        expect(indicator(), '2 / 7');
        await tester.tap(find.byType(Image).first);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('서가로 돌아가기'));
        await tester.pumpAndSettle();
        expect(indicator(), '2 / 7');
      }
    },
  );
}
