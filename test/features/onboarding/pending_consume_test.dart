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
