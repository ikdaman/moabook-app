import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

const serverBook = ReadingBook('71', '서버에서 받은 책', '작가', '출판사', '', '');

class Gateway implements ReadingGateway {
  String? deletedBookId;
  Object? deleteError;
  @override
  Future<void> deleteBook(String bookId) async {
    if (deleteError != null) throw deleteError!;
    deletedBookId = bookId;
    shelfBooks = shelfBooks.where((book) => book.id != bookId).toList();
  }

  bool shelfFails = false, cardFails = false;
  String? savedBookId;
  Object? bookSaveError;
  int shelfLoads = 0, collectionLoads = 0, collectionDetailLoads = 0;
  List<ReadingBook> shelfBooks = [serverBook];
  List<ReadingCollectionSummary> summaries = [];
  int bookPosts = 0;
  ReadingBookCheck? checkResult;
  @override
  Future<ReadingBookCheck> checkBook(
    ReadingBook book, {
    String? collectionId,
  }) async => checkResult ?? ReadingBookCheck(bookId: savedBookId);
  @override
  Future<String> saveBook(ReadingBook book, {required String reason}) async {
    bookPosts++;
    if (bookSaveError != null) throw bookSaveError!;
    return savedBookId = '71';
  }

  Completer<String>? recordWrite;
  Completer<ReadingCollectionDetail>? collectionWrite;
  Object? recordError;
  int recordPosts = 0;
  Future<ReadingShelf>? shelfResponse;
  Future<List<ReadingCollectionSummary>>? collectionsResponse;
  Future<ReadingCollectionDetail>? detailResponse;
  final records = <ReadingRecord>[];
  ReadingCategory? status = ReadingCategory.done;
  @override
  Future<ReadingShelf> loadShelf() async {
    shelfLoads++;
    if (shelfFails) throw StateError('server unavailable');
    if (shelfResponse != null) return await shelfResponse!;
    return ReadingShelf(books: shelfBooks, totalCount: shelfBooks.length);
  }

  @override
  Future<ReadingCard> loadCard(String bookId) async {
    if (cardFails) throw StateError('card unavailable');
    return ReadingCard(
      book: serverBook,
      createdDate: DateTime(2026, 11, 1),
      status: status,
      recordCount: records.length,
    );
  }

  @override
  Future<List<ReadingRecord>> loadRecords(String bookId) async => records;
  @override
  Future<List<ReadingCollectionSummary>> loadCollections() async {
    collectionLoads++;
    if (collectionsResponse != null) return await collectionsResponse!;
    return summaries;
  }

  @override
  Future<ReadingCollectionDetail> loadCollection(String collectionId) async {
    collectionDetailLoads++;
    if (detailResponse != null) return await detailResponse!;
    return ReadingCollectionDetail(
      collection: ReadingCollection(id: collectionId, name: '서버 모음'),
      books: [],
    );
  }

  @override
  Future<ReadingCollectionDetail> createCollection(String name) =>
      collectionWrite!.future;
  @override
  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection collection,
  ) async => ReadingCollectionDetail(collection: collection, books: []);
  Future<ReadingSearchPage> Function(String, int)? search;
  @override
  Future<ReadingSearchPage> searchBooks(String keyword, {int page = 1}) async =>
      search != null
      ? await search!(keyword, page)
      : ReadingSearchPage(
          books: [serverBook],
          page: page,
          hasMore: false,
          totalCount: 1,
        );
  @override
  Future<String> addRecord(
    String bookId, {
    required ReadingCategory category,
    required DateTime date,
    required String memo,
  }) async {
    recordPosts++;
    if (recordError != null) throw recordError!;
    final id =
        await (recordWrite?.future ?? Future.value('initial-$recordPosts'));
    records.add(
      ReadingRecord(id: id, category: category, date: date, memo: memo),
    );
    if (category.changesStatus) status = category;
    return id;
  }
}

class SlotGateway extends Gateway {
  ReadingCollection collection = ReadingCollection(id: '8', name: '슬롯 테스트');
  ReadingCollection? submitted;
  @override
  Future<ReadingCollectionDetail> loadCollection(String collectionId) async =>
      ReadingCollectionDetail(collection: collection, books: [serverBook]);
  @override
  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection value,
  ) async {
    submitted = collection = value;
    return ReadingCollectionDetail(collection: collection, books: [serverBook]);
  }
}

void main() {
  Future<ReadingWorkspaceState> open(
    WidgetTester tester,
    Gateway gateway,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ReadingWorkspace(
        initialMood: Mood.a,
        initialScreen: 'shelf',
        gateway: gateway,
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<ReadingWorkspaceState>(find.byType(ReadingWorkspace));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pump();
  }

  Future<void> enterRecord(
    WidgetTester tester,
    ReadingWorkspaceState state,
  ) async {
    state.openBook(serverBook);
    await tester.pumpAndSettle();
    state.go('record-free');
    state.recordCategory = ReadingCategory.free;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '기억할 내용');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  testWidgets('live slot selection survives save and collection reload', (
    tester,
  ) async {
    final gateway = SlotGateway()
      ..summaries = [
        ReadingCollectionSummary(id: '8', name: '슬롯 테스트', representatives: []),
      ];
    final state = await open(tester, gateway);
    state.go('collection');
    await tester.pumpAndSettle();
    final slot = find.byKey(const ValueKey('collection-slot-8'));
    await tester.ensureVisible(slot);
    await tester.tap(slot);
    await tester.pumpAndSettle();
    expect(state.targetCollectionSlot, 8);
    state.selectedBook = serverBook;
    state.addBookToCollection();
    await tester.pumpAndSettle();
    expect(gateway.submitted!.slots[8], serverBook.id);
    expect(gateway.submitted!.slots.take(8), everyElement(isNull));
    state.go('collection', refreshLibrary: true);
    await tester.pumpAndSettle();
    expect(state.currentCollection.slots[8], serverBook.id);
    expect(state.currentCollection.slots.take(8), everyElement(isNull));
    expect(tester.takeException(), isNull);
  });

  testWidgets('card deletion can be cancelled and confirmed', (tester) async {
    final gateway = Gateway();
    final state = await open(tester, gateway);
    state.openBook(serverBook);
    await tester.pumpAndSettle();
    await tap(tester, '삭제');
    await tester.pumpAndSettle();
    await tap(tester, '취소');
    await tester.pumpAndSettle();
    expect(gateway.deletedBookId, isNull);
    expect(state.screen, 'card-front');
    await tap(tester, '삭제');
    await tester.pumpAndSettle();
    await tap(tester, '삭제');
    await tester.pumpAndSettle();
    expect(gateway.deletedBookId, '71');
    expect(state.screen, 'shelf');
    expect(state.history, isEmpty);
    expect(state.library, isEmpty);
    expect(state.cards.containsKey('71'), isFalse);
    expect(gateway.shelfLoads, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed deletion preserves the card and its records', (
    tester,
  ) async {
    final gateway = Gateway()..deleteError = StateError('offline');
    final state = await open(tester, gateway);
    state.openBook(serverBook);
    await tester.pumpAndSettle();
    await tap(tester, '삭제');
    await tester.pumpAndSettle();
    await tap(tester, '삭제');
    await tester.pumpAndSettle();
    expect(state.screen, 'card-front');
    expect(state.library.containsKey('71'), isTrue);
    expect(state.isSaving, isFalse);
    expect(find.text('책을 삭제하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
  });

  for (final systemBack in [false, true]) {
    testWidgets('saved record back returns to shelf (system: $systemBack)', (
      tester,
    ) async {
      final gateway = Gateway()..recordWrite = Completer<String>();
      final state = await open(tester, gateway);
      await enterRecord(tester, state);
      await tap(tester, '기록 완료');
      gateway.recordWrite!.complete('record-1');
      await tester.pumpAndSettle();
      expect(state.screen, 'record-complete');
      expect(state.history, ['shelf']);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.bySemanticsLabel('뒤로'));
      }
      await tester.pumpAndSettle();
      expect(state.screen, 'shelf');
      expect(find.byType(TextFormField), findsNothing);
      expect(gateway.recordPosts, 1);
    });
  }

  ReadingBook resultBook(int id) =>
      ReadingBook('yes24:$id', '검색 책 $id', '저자', '출판사', '', '', yes24Id: '$id');
  Future<void> submitSearch(
    WidgetTester tester,
    ReadingWorkspaceState state,
    String query,
  ) async {
    if (state.screen != 'search') state.go('search');
    // A previous page may still be loading while the user submits a new query.
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'library tabs reload changed server lists and collection details',
    (tester) async {
      final gateway = Gateway();
      final state = await open(tester, gateway);
      expect(gateway.shelfLoads, 1);
      expect(gateway.collectionLoads, 1);
      gateway.summaries = [
        ReadingCollectionSummary(id: '9', name: '새 컬렉션', representatives: []),
      ];
      await tap(tester, '주제 서가');
      await tester.pumpAndSettle();
      expect(gateway.collectionLoads, 2);
      expect(gateway.collectionDetailLoads, 1);
      expect(state.currentCollection.id, '9');
      gateway.shelfBooks = [
        serverBook,
        const ReadingBook('72', '새 책', '작가', '출판사', '', ''),
      ];
      await tap(tester, '기본 서가');
      await tester.pumpAndSettle();
      expect(gateway.shelfLoads, 2);
      expect(state.library.keys, contains('72'));
      await tap(tester, '주제 서가');
      await tester.pumpAndSettle();
      expect(gateway.collectionLoads, 3);
      expect(gateway.collectionDetailLoads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tab refresh keeps cached shelves visible while requests are pending',
    (tester) async {
      final gateway = Gateway()
        ..summaries = [
          ReadingCollectionSummary(id: '9', name: '서버 모음', representatives: []),
        ];
      final state = await open(tester, gateway);
      await tap(tester, '주제 서가');
      await tester.pumpAndSettle();
      final shelf = Completer<ReadingShelf>();
      gateway.shelfResponse = shelf.future;
      await tap(tester, '기본 서가');
      expect(find.byKey(const Key('shelf-pager')), findsOneWidget);
      expect(find.byKey(const ValueKey('spine-71')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      shelf.complete(ReadingShelf(books: [serverBook], totalCount: 1));
      await tester.pumpAndSettle();
      final summaries = Completer<List<ReadingCollectionSummary>>();
      final detail = Completer<ReadingCollectionDetail>();
      gateway.collectionsResponse = summaries.future;
      gateway.detailResponse = detail.future;
      await tap(tester, '주제 서가');
      expect(find.byKey(const Key('collection-pager')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      summaries.complete(gateway.summaries);
      await tester.pump();
      expect(state.loadedCollections, contains('9'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      detail.complete(
        ReadingCollectionDetail(
          collection: ReadingCollection(id: '9', name: '갱신된 모음'),
          books: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(state.currentCollection.name, '갱신된 모음');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'boundary transitions defer refresh until after sliding and reverse server order',
    (tester) async {
      final gateway = Gateway()
        ..summaries = [
          ReadingCollectionSummary(
            id: '1',
            name: '먼저 만든 모음',
            representatives: [],
          ),
          ReadingCollectionSummary(
            id: '2',
            name: '나중에 만든 모음',
            representatives: [],
          ),
        ];
      final state = await open(tester, gateway);
      expect(state.collectionData.map((c) => c.id), ['2', '1']);
      expect(gateway.collectionLoads, 1);
      expect(gateway.collectionDetailLoads, 0);
      await tester.drag(
        find.byKey(const Key('shelf-pager')),
        const Offset(-300, 0),
      );
      await tester.pump();
      expect(state.screen, 'collection');
      expect(gateway.collectionLoads, 1);
      expect(gateway.collectionDetailLoads, 0);
      await tester.pump(const Duration(milliseconds: 140));
      expect(gateway.collectionLoads, 1);
      expect(gateway.collectionDetailLoads, 0);
      await tester.pumpAndSettle();
      expect(gateway.collectionLoads, 2);
      expect(gateway.collectionDetailLoads, 1);
      expect(state.currentCollection.id, '2');
      final delayed = Completer<ReadingShelf>();
      gateway.shelfResponse = delayed.future;
      await tester.drag(
        find.byKey(const Key('collection-pager')),
        const Offset(300, 0),
      );
      await tester.pump();
      expect(state.screen, 'shelf');
      expect(gateway.shelfLoads, 1);
      await tester.pump(const Duration(milliseconds: 140));
      expect(gateway.shelfLoads, 1);
      await tester.pumpAndSettle();
      expect(gateway.shelfLoads, 2);
      expect(find.byKey(const ValueKey('spine-71')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      delayed.complete(ReadingShelf(books: [serverBook], totalCount: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrolling appends pages, reuses submitted query and removes duplicates',
    (tester) async {
      final calls = <String>[];
      final gateway = Gateway()
        ..search = (query, page) async {
          calls.add('$query:$page');
          return ReadingSearchPage(
            books: page == 1
                ? [for (var id = 1; id <= 8; id++) resultBook(id)]
                : [resultBook(8), resultBook(9)],
            page: page,
            hasMore: page == 1,
            totalCount: 9,
          );
        };
      final state = await open(tester, gateway);
      await submitSearch(tester, state, '첫 검색');
      expect(find.text('8 / 9권'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        '아직 제출하지 않은 검색어',
      );
      tester.testTextInput.hide();
      state.scroll.jumpTo(state.scroll.position.maxScrollExtent - 250);
      await tester.pumpAndSettle();
      expect(calls, ['첫 검색:1', '첫 검색:2']);
      expect(state.remoteSearchResults.map((b) => b.id), [
        for (var id = 1; id <= 9; id++) 'yes24:$id',
      ]);
      expect(find.text('더 불러오기'), findsNothing);
      expect(find.text('9 / 9권'), findsOneWidget);
    },
  );

  testWidgets('failed next page preserves results and retries the same page', (
    tester,
  ) async {
    var fail = true;
    final pages = <int>[];
    final gateway = Gateway()
      ..search = (query, page) async {
        pages.add(page);
        if (page == 2 && fail) throw StateError('offline');
        return ReadingSearchPage(
          books: page == 1
              ? [for (var id = 1; id <= 6; id++) resultBook(id)]
              : [resultBook(7)],
          page: page,
          hasMore: page == 1,
          totalCount: 7,
        );
      };
    final state = await open(tester, gateway);
    await submitSearch(tester, state, '책');
    state.scroll.jumpTo(state.scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(state.remoteSearchResults.length, 6);
    expect(state.remoteSearchPage, 1);
    expect(find.text('다시 불러오기'), findsOneWidget);
    state.scroll.jumpTo(state.scroll.position.maxScrollExtent - 10);
    await tester.pumpAndSettle();
    expect(pages, [1, 2]);
    fail = false;
    await tap(tester, '다시 불러오기');
    await tester.pumpAndSettle();
    expect(pages, [1, 2, 2]);
    expect(state.remoteSearchResults.length, 7);
  });

  testWidgets(
    'short search pages fill the viewport and stop at the last page',
    (tester) async {
      final pages = <int>[];
      final gateway = Gateway()
        ..search = (query, page) async {
          pages.add(page);
          return ReadingSearchPage(
            books: [resultBook(page)],
            page: page,
            hasMore: page < 3,
            totalCount: 3,
          );
        };
      final state = await open(tester, gateway);
      await submitSearch(tester, state, '책');
      expect(pages, [1, 2, 3]);
      expect(state.remoteSearchResults.length, 3);
      expect(find.text('더 불러오기'), findsNothing);
      state.scroll.jumpTo(state.scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(pages, [1, 2, 3]);
    },
  );

  testWidgets('late next page cannot overwrite a new search', (tester) async {
    final delayed = Completer<ReadingSearchPage>();
    var moreCalls = 0;
    final gateway = Gateway()
      ..search = (query, page) async {
        if (page == 2) {
          moreCalls++;
          return delayed.future;
        }
        return ReadingSearchPage(
          books: query == '이전'
              ? [for (var id = 1; id <= 6; id++) resultBook(id)]
              : [resultBook(9)],
          page: 1,
          hasMore: query == '이전',
          totalCount: query == '이전' ? 7 : 1,
        );
      };
    final state = await open(tester, gateway);
    await submitSearch(tester, state, '이전');
    state.scroll.jumpTo(state.scroll.position.maxScrollExtent);
    await tester.pump();
    state.scroll.jumpTo(state.scroll.position.maxScrollExtent - 1);
    await tester.pump();
    expect(moreCalls, 1);
    await submitSearch(tester, state, '새 검색');
    delayed.complete(
      ReadingSearchPage(
        books: [resultBook(2)],
        page: 2,
        hasMore: false,
        totalCount: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(state.remoteSearchResults.single.id, 'yes24:9');
    expect(state.remoteSearchPage, 1);
    expect(state.loadingMoreSearch, isFalse);
    expect(state.remoteSearchTotalCount, 1);
  });

  testWidgets('add options keep barcode scanning and remove photo inputs', (
    tester,
  ) async {
    final state = await open(tester, Gateway());
    state.go('add-options');
    await tester.pumpAndSettle();
    expect(find.text('바코드 스캔'), findsOneWidget);
    expect(find.text('갤러리 사진 불러오기'), findsNothing);
    expect(find.text('책 표지나 바코드 촬영'), findsNothing);
  });

  const searchBook = ReadingBook(
    'yes24:123',
    '새 책',
    '작가',
    '출판사',
    '',
    '',
    yes24Id: '123',
  );

  testWidgets(
    'new book saves its selected initial status before allowing further records',
    (tester) async {
      final gateway = Gateway()
        ..status = null
        ..recordWrite = (Completer<String>()..complete('5'));
      final state = await open(tester, gateway);
      state.selectedBook = searchBook;
      state.confirmBook();
      await tester.pumpAndSettle();
      expect(state.screen, 'save-wish');
      expect(find.text('읽기 시작한 날'), findsNothing);
      state.reasonDraft = '읽고 싶은 이유';
      state.saveBookLocally();
      await tester.pumpAndSettle();
      expect(gateway.bookPosts, 1);
      expect(gateway.recordPosts, 1);
      expect(gateway.records.single.category, ReadingCategory.todo);
      expect(gateway.records.single.memo, '읽고 싶은 이유');
      expect(state.screen, 'card-back');
      expect(state.selectedBook.id, '71');
      expect(find.text('기록 추가'), findsOneWidget);
      await tap(tester, '기록 추가');
      await tester.pumpAndSettle();
      expect(state.screen, 'record-options');
      expect(gateway.recordPosts, 1);
      await tap(tester, '자유 기록');
      await tester.pumpAndSettle();
      expect(state.screen, 'record-free');
      await tester.enterText(find.byType(TextFormField).first, '첫 기억');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, '기록 완료');
      await tester.pumpAndSettle();
      expect(gateway.bookPosts, 1);
      expect(gateway.recordPosts, 2);
      expect(gateway.records.last.memo, '첫 기억');
      expect(state.screen, 'record-complete');
    },
  );

  for (final category in [ReadingCategory.inProgress, ReadingCategory.done]) {
    testWidgets(
      'new book saves ${category.code} with the chosen date and no hidden reason',
      (tester) async {
        final gateway = Gateway()..status = null;
        final state = await open(tester, gateway);
        state.selectedBook = searchBook;
        state.confirmBook();
        await tester.pumpAndSettle();
        final date = DateTime(2026, 5, 7);
        state.bookSaveCategory = category;
        state.startedDate = state.finishedDate = date;
        state.reasonDraft = '숨겨진 이전 입력';
        state.saveBookLocally();
        await tester.pumpAndSettle();
        expect(gateway.bookPosts, 1);
        expect(gateway.records.single.category, category);
        expect(gateway.records.single.date, date);
        expect(gateway.records.single.memo, isEmpty);
        expect(state.readingStatus, category.label);
      },
    );
  }

  testWidgets('uncertain initial status never repeats book or record writes', (
    tester,
  ) async {
    final gateway = Gateway()..recordError = const ReadingWriteUncertain();
    final state = await open(tester, gateway);
    state.selectedBook = searchBook;
    state.confirmBook();
    await tester.pumpAndSettle();
    state.saveBookLocally();
    await tester.pumpAndSettle();
    state.saveBookLocally();
    await tester.pumpAndSettle();
    expect(gateway.bookPosts, 1);
    expect(gateway.recordPosts, 1);
    expect(find.text('독서카드에서 저장 결과 확인'), findsOneWidget);
    expect(state.operationError, contains('독서 상태의 저장 결과'));
  });

  for (final category in [
    ReadingCategory.todo,
    ReadingCategory.inProgress,
    ReadingCategory.done,
  ]) {
    testWidgets('record options preselect the current ${category.code} state', (
      tester,
    ) async {
      final gateway = Gateway()
        ..records.add(
          ReadingRecord(
            id: '1',
            category: category,
            date: DateTime(2026, 11, 1),
            memo: '',
          ),
        );
      final state = await open(tester, gateway);
      state.openBook(serverBook);
      await tester.pumpAndSettle();
      state.go('record-options');
      await tester.pumpAndSettle();
      expect(state.selectedRecordStatus, category);
      expect(state.recordCategory, category);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
        findsOneWidget,
      );
      state.chooseCategory(ReadingCategory.buy);
      await tester.pumpAndSettle();
      state.go('record-options');
      await tester.pumpAndSettle();
      expect(state.selectedRecordStatus, category);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
        findsNWidgets(2),
      );
    });
  }

  testWidgets(
    'ordinary record selection stays in the sheet and posts once on completion',
    (tester) async {
      final gateway = Gateway()..recordWrite = Completer<String>();
      final state = await open(tester, gateway);
      state.openBook(serverBook);
      await tester.pumpAndSettle();
      state.go('record-options');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-DONE')));
      await tester.pumpAndSettle();
      expect(state.screen, 'record-options');
      expect(gateway.recordPosts, 0);
      expect(find.byType(TextFormField), findsNothing);
      await tap(tester, '기록 완료');
      expect(gateway.recordPosts, 1);
      state.saveRecordLocally();
      expect(gateway.recordPosts, 1);
      gateway.recordWrite!.complete('once');
      await tester.pumpAndSettle();
      expect(gateway.records.single.category, ReadingCategory.done);
      expect(gateway.records.single.memo, isEmpty);
      expect(state.screen, 'record-complete');
    },
  );

  testWidgets('uncertain book write checks before any retry', (tester) async {
    final gateway = Gateway()..bookSaveError = const ReadingWriteUncertain();
    final state = await open(tester, gateway);
    state.selectedBook = searchBook;
    state.confirmBook();
    await tester.pumpAndSettle();
    state.saveBookLocally();
    await tester.pumpAndSettle();
    state.saveBookLocally();
    await tester.pumpAndSettle();
    expect(gateway.bookPosts, 1);
    expect(gateway.recordPosts, 0);
    expect(state.operationError, contains('저장 결과를 아직 확인하지 못했어요'));
    gateway.savedBookId = '71';
    state.saveBookLocally();
    await tester.pumpAndSettle();
    expect(gateway.bookPosts, 1);
    expect(gateway.recordPosts, 1);
    expect(state.screen, 'card-back');
  });

  testWidgets('duplicate check opens existing book without a write', (
    tester,
  ) async {
    final gateway = Gateway()
      ..checkResult = const ReadingBookCheck(bookId: '71');
    final state = await open(tester, gateway);
    state.selectedBook = searchBook;
    state.confirmBook();
    await tester.pumpAndSettle();
    expect(state.screen, 'duplicate');
    expect(state.selectedBook.id, '71');
    expect(gateway.bookPosts, 0);
    expect(gateway.recordPosts, 0);
  });

  testWidgets(
    'card refresh failure preserves saved book and never repeats its writes',
    (tester) async {
      final gateway = Gateway()
        ..cardFails = true
        ..recordWrite = (Completer<String>()..complete('8'));
      final state = await open(tester, gateway);
      state.selectedBook = searchBook;
      state.confirmBook();
      await tester.pumpAndSettle();
      state.saveBookLocally();
      await tester.pumpAndSettle();
      expect(state.operationError, contains('책은 저장됐지만'));
      gateway.cardFails = false;
      state.saveBookLocally();
      await tester.pumpAndSettle();
      expect(gateway.bookPosts, 1);
      expect(gateway.recordPosts, 1);
      expect(state.screen, 'card-back');
    },
  );

  testWidgets(
    'collection duplicate check opens its duplicate notice without writing',
    (tester) async {
      final gateway = Gateway()
        ..checkResult = const ReadingBookCheck(
          bookId: '71',
          alreadyInCollection: true,
        );
      final state = await open(tester, gateway);
      state.collectionData = [ReadingCollection(id: '8', name: '내 모음')];
      state.targetCollectionId = '8';
      state.selectedBook = searchBook;
      state.confirmBook();
      await tester.pumpAndSettle();
      expect(state.screen, 'collection-duplicate');
      expect(gateway.bookPosts, 0);
      expect(gateway.recordPosts, 0);
    },
  );

  testWidgets('failed live shelf shows retry without any preview books', (
    tester,
  ) async {
    final gateway = Gateway()..shelfFails = true;
    final state = await open(tester, gateway);
    expect(find.text('서가를 불러오지 못했어요.'), findsOneWidget);
    expect(state.library, isEmpty);
    expect(find.text('소년과 두더지와 여우와 말'), findsNothing);
    gateway.shelfFails = false;
    await tap(tester, '다시 시도');
    await tester.pumpAndSettle();
    expect(state.library.keys, ['71']);
    expect(state.totalShelfCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card status uses dated records instead of the server summary', (
    tester,
  ) async {
    final gateway = Gateway()
      ..records.add(
        ReadingRecord(
          id: '1',
          category: ReadingCategory.inProgress,
          date: DateTime(2026, 11, 3),
          memo: '',
        ),
      );
    final state = await open(tester, gateway);
    state.openBook(serverBook);
    await tester.pumpAndSettle();
    expect(state.readingStatus, ReadingCategory.inProgress.label);
    expect(state.journal.status, ReadingCategory.inProgress);
    expect(state.library.keys, ['71']);
  });

  testWidgets('record waits for server ID and prevents a second submission', (
    tester,
  ) async {
    final gateway = Gateway()..recordWrite = Completer<String>();
    final state = await open(tester, gateway);
    await enterRecord(tester, state);
    await tap(tester, '기록 완료');
    expect(state.screen, 'record-free');
    expect(state.isSaving, isTrue);
    expect(state.completedRecord, isNull);
    state.saveRecordLocally();
    expect(gateway.recordPosts, 1);
    gateway.recordWrite!.complete('902');
    await tester.pumpAndSettle();
    expect(state.screen, 'record-complete');
    expect(state.completedRecord!.id, '902');
    expect(state.journal.records.single.memo, '기억할 내용');
    expect(tester.takeException(), isNull);
  });

  testWidgets('record error preserves draft and never shows success', (
    tester,
  ) async {
    final gateway = Gateway()..recordError = StateError('rejected');
    final state = await open(tester, gateway);
    await enterRecord(tester, state);
    await tap(tester, '기록 완료');
    await tester.pumpAndSettle();
    expect(state.screen, 'record-free');
    expect(state.memoDraft, '기억할 내용');
    expect(state.completedRecord, isNull);
    expect(find.text('기록을 저장하지 못했어요. 입력은 그대로 남아 있어요.'), findsOneWidget);
  });

  testWidgets('uncertain write offers read-back instead of another POST', (
    tester,
  ) async {
    final gateway = Gateway()..recordError = const ReadingWriteUncertain();
    final state = await open(tester, gateway);
    await enterRecord(tester, state);
    await tap(tester, '기록 완료');
    await tester.pumpAndSettle();
    expect(state.recordWriteUncertain, isTrue);
    expect(find.text('기록 목록에서 저장 결과 확인'), findsOneWidget);
    state.saveRecordLocally();
    await tester.pumpAndSettle();
    expect(gateway.recordPosts, 1);
    expect(state.memoDraft, '기억할 내용');
  });

  testWidgets(
    'created collection uses returned server ID and nine empty slots',
    (tester) async {
      final gateway = Gateway()
        ..collectionWrite = Completer<ReadingCollectionDetail>();
      final state = await open(tester, gateway);
      state.go('collection-create');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '새 모음');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tap(tester, '컬렉션 만들기');
      expect(state.collectionData, isEmpty);
      expect(state.isSaving, isTrue);
      gateway.collectionWrite!.complete(
        ReadingCollectionDetail(
          collection: ReadingCollection(id: '808', name: '새 모음'),
          books: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(state.currentCollection.id, '808');
      expect(state.currentCollection.slots, List<String?>.filled(9, null));
      expect(state.screen, 'collection');
      expect(tester.takeException(), isNull);
    },
  );
}
