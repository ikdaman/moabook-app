import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/design_preview/preview_app.dart';
import 'package:moabook/design_preview/widgets/policy_widgets.dart';
import 'package:moabook_reading/moabook_reading.dart';

void main() {
  Future<DesignPreviewState> open(WidgetTester tester, String screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DesignPreviewApp(initialScreen: screen));
    await tester.pumpAndSettle();
    return tester.state<DesignPreviewState>(find.byType(DesignPreview));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField).first, text);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  for (final screen in ['record-options', 'add-options']) {
    testWidgets('$screen content clears the system navigation area', (
      tester,
    ) async {
      await open(tester, screen);
      final label = screen == 'record-options' ? '자유 기록' : '책 제목으로 검색';
      // Compare the same sheet with and without an Android navigation inset.
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final before = tester.getBottomLeft(finder).dy;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(finder).dy, closeTo(before - 48, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('record action stays visible while a long card list scrolls', (
    tester,
  ) async {
    final state = await open(tester, 'card-back');
    state.journals[state.book.id] = ReadingJournal(
      List.generate(
        30,
        (i) => ReadingRecord(
          id: 'long-$i',
          category: ReadingCategory.free,
          date: DateTime(2026, 11, 1),
          memo: '기록 $i: 오래 기억할 책 속의 순간입니다.',
        ),
      ),
    );
    state.flipCard('card-back');
    await tester.pumpAndSettle();
    final action = find.text('기록 추가');
    final before = tester.getCenter(action);
    await tester.drag(
      find.byKey(const ValueKey('card-record-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(state.scroll.offset, greaterThan(0));
    expect(tester.getCenter(action), before);
    expect(action.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(
        tester
            .getBottomLeft(find.byKey(const ValueKey('card-record-surface')))
            .dy,
      ),
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(state.screen, 'record-options');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty card keeps guidance inside and record action outside', (
    tester,
  ) async {
    await open(tester, 'card-empty');
    final card = find.byKey(const ValueKey('card-record-surface'));
    final action = find.byKey(const ValueKey('card-add-record'));
    expect(
      find.descendant(of: card, matching: find.text('첫 번째 기억을 남겨보세요')),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: action), findsNothing);
    expect(find.text('첫 기록 남기기'), findsNothing);
    expect(
      tester.getTopLeft(action).dy,
      greaterThan(tester.getBottomLeft(card).dy),
    );
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    final state = tester.state<ReadingWorkspaceState>(
      find.byType(ReadingWorkspace),
    );
    expect(state.screen, 'record-options');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'record bottom sheets omit the repeated book thumbnail and metadata',
    (tester) async {
      final state = await open(tester, 'record-options');
      for (final screen in ['record-options', 'record-entry']) {
        state.go(screen);
        await tester.pumpAndSettle();
        // Only the overlay subtree is inspected; the underlying card keeps its book details.
        final text = find.text(state.book.title);
        expect(text.hitTestable(), findsNothing);
        expect(find.text(state.book.author).hitTestable(), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('book metadata has bold horizontal rules and stronger values', (
    tester,
  ) async {
    final state = await open(tester, 'book-info');
    final metadata = tester.widget<Container>(
      find.byKey(const ValueKey('book-info-metadata')),
    );
    final border = (metadata.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 3);
    expect(border.bottom.width, 3);
    expect(border.left.style, BorderStyle.none);
    final pageText = tester.widget<Text>(find.text('${state.book.totalPage}쪽'));
    expect(pageText.style!.fontSize, 16);
    expect(pageText.style!.fontFamily, 'PlexMono');
    expect(state.formatPublicationDate('2026-11-10'), '2026.11.10');
    expect(state.reasonTextColor(''), Colors.white);
  });

  testWidgets(
    'creation sheet preserves the collection list and scroll while opening and closing',
    (tester) async {
      final state = await open(tester, 'collections');
      state.collectionData.addAll(
        List.generate(
          20,
          (i) => ReadingCollection(id: 'extra-$i', name: '모음 $i'),
        ),
      );
      state.go('collections');
      await tester.pumpAndSettle();
      state.scroll.jumpTo(80);
      await tester.pumpAndSettle();
      final background = tester.element(
        find.byKey(const ValueKey('collections')),
      );
      state.go('collection-create');
      for (final elapsed in [0, 80, 200]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(
          tester.element(find.byKey(const ValueKey('collections'))),
          same(background),
        );
        expect(find.byKey(const Key('collection-pager')), findsNothing);
        expect(state.scroll.offset, 80);
      }
      state.back();
      for (final elapsed in [0, 80, 200]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(
          tester.element(find.byKey(const ValueKey('collections'))),
          same(background),
        );
        expect(state.scroll.offset, 80);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('creation sheet keeps the last pager page mounted', (
    tester,
  ) async {
    final state = await open(tester, 'collection');
    state.collectionPages.jumpToPage(state.collectionData.length);
    await tester.pumpAndSettle();
    final pager = tester.element(find.byKey(const Key('collection-pager')));
    state.go('collection-create');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.element(find.byKey(const Key('collection-pager'))),
      same(pager),
    );
    expect(state.collectionPages.page, state.collectionData.length.toDouble());
    expect(find.text('나의 컬렉션'), findsNothing);
    state.back();
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const Key('collection-pager'))),
      same(pager),
    );
    expect(state.collectionPages.page, state.collectionData.length.toDouble());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creation requires a name and opens a new collection with nine empty slots',
    (tester) async {
      final state = await open(tester, 'collections');
      await tap(tester, find.text('새 컬렉션'));
      await tap(tester, find.text('컬렉션 만들기'));
      expect(state.collectionData.length, 6);
      await enter(tester, '  가을의 책  ');
      await tap(tester, find.text('컬렉션 만들기'));
      expect(state.currentCollection.name, '가을의 책');
      expect(state.currentCollection.slots, List<String?>.filled(9, null));
      expect(state.screen, 'collection');
      expect(find.byType(CollectionSlotGrid), findsWidgets);
      expect(find.text('한 줄 소개 · 선택'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing removes one book without moving others or changing the library',
    (tester) async {
      final state = await open(tester, 'collection');
      final before = state.currentCollection.slots.toList();
      final bookCount = state.library.length;
      final originalName = state.currentCollection.name;
      await tap(tester, find.text('편집'));
      await enter(tester, '바꾼 이름');
      await tap(tester, find.byKey(const ValueKey('remove-slot-0')));
      expect(state.currentCollection.name, originalName);
      expect(state.currentCollection.slots, before);
      await tap(tester, find.text('편집 완료'));
      expect(state.currentCollection.name, '바꾼 이름');
      expect(state.currentCollection.slots.first, isNull);
      expect(state.currentCollection.slots.skip(1), before.skip(1));
      expect(state.library.length, bookCount);
      expect(state.library.containsKey(before.first), isTrue);
    },
  );

  testWidgets(
    'tapping the ninth empty slot saves there without filling the first slot',
    (tester) async {
      final state = await open(tester, 'collection-empty');
      await tap(tester, find.byKey(const ValueKey('collection-slot-8')));
      expect(state.targetCollectionSlot, 8);
      state.selectedBook = state.library.values.first;
      state.confirmBook();
      await tester.pumpAndSettle();
      expect(state.currentCollection.slots[8], state.selectedBook.id);
      expect(state.currentCollection.slots.take(8), everyElement(isNull));
      expect(state.targetCollectionSlot, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('very thick spines use the capped width without overflow', (
    tester,
  ) async {
    final state = await open(tester, 'shelf');
    state.library.clear();
    state.library['thick'] = const ReadingBook(
      'thick',
      '두꺼운 책',
      '작가',
      '',
      '',
      '',
      totalPage: 10000,
    );
    state.go('shelf');
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('spine-thick'))).width,
      bookSpineWidth(10000),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'collection add reuses a saved book and repeated add shows collection-specific duplicate',
    (tester) async {
      final state = await open(tester, 'collection-empty');
      final bookCount = state.library.length;
      Future<void> chooseFirstBook() async {
        await tap(
          tester,
          find.bySemanticsLabel(RegExp('번 빈 칸, 책 추가')).hitTestable().first,
        );
        await tap(tester, find.text('책 제목으로 검색'));
        await tap(tester, find.text('소년과 두더지와 여우와 말'));
        await tap(tester, find.text('컬렉션에 담기'));
      }

      await chooseFirstBook();
      expect(state.screen, 'collection');
      expect(state.currentCollection.slots.first, 'boy');
      expect(state.library.length, bookCount);
      await chooseFirstBook();
      expect(find.text('이미 이 컬렉션에 담긴 책이에요'), findsOneWidget);
      await tap(tester, find.text('확인'));
      expect(state.screen, 'book-info');
      expect(state.currentCollection.slots.whereType<String>(), ['boy']);
    },
  );

  testWidgets('new collection book saves the selected initial status', (
    tester,
  ) async {
    final state = await open(tester, 'collection-empty');
    await tap(tester, find.bySemanticsLabel('1번 빈 칸, 책 추가').hitTestable());
    await tap(tester, find.text('책 제목으로 검색'));
    await enter(tester, '다음 계절');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tap(tester, find.text('다음 계절에 읽을 책').last);
    await tap(tester, find.text('컬렉션에 담기'));
    expect(state.screen, 'save-wish');
    expect(find.text('읽기 시작한 날'), findsNothing);
    await tap(tester, find.text('저장하기'));
    expect(state.screen, 'collection');
    expect(state.currentCollection.slots.first, 'new-book');
    final journal = state.journals['new-book']!;
    expect(journal.records.length, 1);
    expect(journal.status, ReadingCategory.todo);
  });

  testWidgets(
    'initial TODO stores its reason and a later empty TODO clears the band',
    (tester) async {
      final state = await open(tester, 'save-wish');
      state.reasonDraft = '서점에서 만난 책';
      state.saveBookLocally();
      await tester.pumpAndSettle();
      expect(state.screen, 'card-front');
      expect(find.text('책이 잘 저장되었습니다!'), findsOneWidget);
      expect(state.journal.records.length, 1);
      expect(state.book.reason, '서점에서 만난 책');
      await tester.drag(
        find.byKey(const ValueKey('card-front-surface')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('기록 추가'), findsOneWidget);
      state.chooseCategory(ReadingCategory.todo);
      state.memoDraft = '';
      state.saveRecordLocally();
      await tester.pumpAndSettle();
      expect(state.journal.records.length, 2);
      expect(state.book.reason, isEmpty);
    },
  );

  testWidgets(
    'FREE validates whitespace and completed record retains actual content and date',
    (tester) async {
      final state = await open(tester, 'record-free');
      await enter(tester, List.filled(401, '글').join());
      expect(state.memoDraft.characters.length, 400);
      expect(find.text('400/400'), findsOneWidget);
      await enter(tester, '  ');
      await tap(tester, find.text('기록 완료'));
      expect(state.screen, 'record-free');
      await enter(tester, '기억할 문장');
      final chosen = state.recordDate;
      await tap(tester, find.text('기록 완료'));
      expect(state.screen, 'record-complete');
      expect(find.text('기억할 문장'), findsOneWidget);
      expect(find.text(DesignPreviewState.formatDate(chosen)), findsOneWidget);
      expect(state.journal.records.last.memo, '기억할 문장');
      expect(state.journal.status, ReadingCategory.inProgress);
      await tap(tester, find.text('독서카드로 돌아가기'));
      expect(state.screen, 'card-back');
      expect(find.text('기억할 문장'), findsOneWidget);
    },
  );

  testWidgets('every category opens its input screen before saving', (
    tester,
  ) async {
    final state = await open(tester, 'record-options');
    expect(find.text('쉬고 있음'), findsNothing);
    expect(find.text('기록 완료'), findsNothing);
    for (final category in ReadingCategory.values.where(
      (c) => c != ReadingCategory.free,
    )) {
      await tap(tester, find.byKey(ValueKey('category-${category.code}')));
      expect(state.screen, 'record-entry');
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('기록 완료'), findsOneWidget);
      expect(find.text('자유 기록'), findsNothing);
      expect(state.recordCategory, category);
      expect(state.completedRecord, isNull);
      if (category == ReadingCategory.todo) {
        expect(find.text('읽고 싶은 이유'), findsOneWidget);
        expect(find.text('0/400'), findsOneWidget);
      } else {
        expect(find.text('어떤 기억을 남기고 싶나요?'), findsOneWidget);
        expect(find.text('0/400'), findsOneWidget);
      }
      expect(find.text('· 선택'), findsOneWidget);
      await enter(tester, List.filled(401, '글').join());
      expect(state.memoDraft.characters.length, 400);
      expect(find.text('400/400'), findsOneWidget);
      state.back();
      await tester.pumpAndSettle();
    }
    await tap(tester, find.byKey(const ValueKey('category-BUY')));
    await enter(tester, '서점에서 만난 책');
    await tap(tester, find.text('기록 완료'));
    expect(state.screen, 'record-complete');
    expect(state.completedRecord!.category, ReadingCategory.buy);
    expect(state.completedRecord!.memo, '서점에서 만난 책');
  });

  testWidgets(
    'free record opens text entry and cancellation restores the selected category',
    (tester) async {
      final state = await open(tester, 'record-options');
      await tap(tester, find.text('자유 기록'));
      expect(state.screen, 'record-free');
      expect(find.byType(TextFormField), findsOneWidget);
      await enter(tester, '취소할 기록');
      state.back();
      await tester.pumpAndSettle();
      expect(state.screen, 'record-options');
      expect(state.recordCategory, state.currentBookStatus);
      expect(state.memoDraft, isEmpty);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets(
    'changing category from free text returns without leaving a hidden input route',
    (tester) async {
      final state = await open(tester, 'card-front');
      state.go('record-options');
      await tester.pumpAndSettle();
      await tap(tester, find.text('자유 기록'));
      await tap(tester, find.text('카테고리 바꾸기'));
      expect(state.screen, 'record-options');
      expect(state.recordCategory, state.currentBookStatus);
      state.back();
      await tester.pumpAndSettle();
      expect(state.screen, 'card-front');
    },
  );

  testWidgets(
    'calendar supports month navigation and cancel preserves original date',
    (tester) async {
      final state = await open(tester, 'record-entry');
      final original = state.recordDate;
      await tap(tester, find.text(DesignPreviewState.formatDate(original)));
      await tap(tester, find.byTooltip('이전 달'));
      final previous = DateTime(original.year, original.month - 1, 1);
      await tap(
        tester,
        find.byKey(
          ValueKey('calendar-day-${previous.year}-${previous.month}-1'),
        ),
      );
      await tap(tester, find.bySemanticsLabel('닫기').last);
      expect(state.recordDate, original);
      await tap(tester, find.text(DesignPreviewState.formatDate(original)));
      await tap(tester, find.byTooltip('이전 달'));
      await tap(
        tester,
        find.byKey(
          ValueKey('calendar-day-${previous.year}-${previous.month}-1'),
        ),
      );
      await tap(
        tester,
        find.text('${DesignPreviewState.formatDate(previous)} 선택'),
      );
      expect(state.recordDate, previous);
      expect(
        find.text(DesignPreviewState.formatDate(previous)),
        findsOneWidget,
      );
    },
  );

  testWidgets('records and state are isolated between books', (tester) async {
    final state = await open(tester, 'card-front');
    await tap(tester, find.text('추가하기'));
    await tap(tester, find.byKey(const ValueKey('category-DONE')));
    await tap(tester, find.text('기록 완료'));
    expect(state.journals['boy']!.status, ReadingCategory.done);
    state.openBook(state.library['human']!);
    await tester.pumpAndSettle();
    expect(state.readingStatus, '읽는 중');
    expect(state.journal.records.length, 3);
  });

  testWidgets('cancelled edits preserve collection name and slot assignments', (
    tester,
  ) async {
    final state = await open(tester, 'collection');
    final original = state.currentCollection;
    await tap(tester, find.text('편집'));
    await enter(tester, '취소할 이름');
    await tap(tester, find.byKey(const ValueKey('remove-slot-0')));
    state.back();
    await tester.pumpAndSettle();
    expect(state.currentCollection.name, original.name);
    expect(state.currentCollection.slots, original.slots);
  });

  testWidgets(
    'long record can be completed on a narrow screen with keyboard space',
    (tester) async {
      final state = await open(tester, 'record-free');
      tester.view.physicalSize = const Size(320, 740);
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final text = List.filled(400, '글').join();
      await enter(tester, text);
      await tap(tester, find.text('기록 완료'));
      expect(state.completedRecord!.memo, text);
      expect(tester.takeException(), isNull);
    },
  );
}
