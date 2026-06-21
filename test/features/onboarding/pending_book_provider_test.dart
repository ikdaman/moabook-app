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
