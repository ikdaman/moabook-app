import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

const serverBook = ReadingBook('71', '서버에서 받은 책', '작가', '출판사', '', '');

class Gateway implements ReadingGateway {
  bool shelfFails = false;
  Completer<String>? recordWrite;
  Completer<ReadingCollectionDetail>? collectionWrite;
  Object? recordError;
  int recordPosts = 0;
  final records = <ReadingRecord>[];
  ReadingCategory status = ReadingCategory.done;
  @override
  Future<ReadingShelf> loadShelf() async {
    if (shelfFails) throw StateError('server unavailable');
    return ReadingShelf(books: [serverBook], totalCount: 1);
  }

  @override
  Future<ReadingCard> loadCard(String bookId) async => ReadingCard(
    book: serverBook,
    createdDate: DateTime(2026, 11, 1),
    status: status,
    recordCount: records.length,
  );
  @override
  Future<List<ReadingRecord>> loadRecords(String bookId) async => records;
  @override
  Future<List<ReadingCollectionSummary>> loadCollections() async => [];
  @override
  Future<ReadingCollectionDetail> loadCollection(String collectionId) async =>
      ReadingCollectionDetail(
        collection: ReadingCollection(id: collectionId, name: '서버 모음'),
        books: [],
      );
  @override
  Future<ReadingCollectionDetail> createCollection(String name) =>
      collectionWrite!.future;
  @override
  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection collection,
  ) async => ReadingCollectionDetail(collection: collection, books: []);
  @override
  Future<List<ReadingBook>> searchBooks(String keyword) async => [serverBook];
  @override
  Future<String> addRecord(
    String bookId, {
    required ReadingCategory category,
    required DateTime date,
    required String memo,
  }) async {
    recordPosts++;
    if (recordError != null) throw recordError!;
    final id = await recordWrite!.future;
    records.add(
      ReadingRecord(id: id, category: category, date: date, memo: memo),
    );
    if (category.changesStatus) status = category;
    return id;
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

  testWidgets('server current status wins over the dated timeline', (
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
    expect(state.readingStatus, ReadingCategory.done.label);
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
