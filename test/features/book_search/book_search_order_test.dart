import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/data/datasource/book_catalog_datasource.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/book_search/provider/book_search_provider.dart';

class ControlledCatalog implements BookCatalogDataSource {
  final pending = <String, Completer<List<BookItem>>>{};
  @override
  Future<List<BookItem>> searchByTitle(
    String query, {
    int page = 1,
    bool byKeyword = false,
  }) => (pending['$query:$page'] = Completer<List<BookItem>>()).future;
  @override
  Future<List<BookItem>> searchByIsbn(String isbn) async => [];
}

BookItem book(int id) => BookItem(
  title: '책 $id',
  author: '저자',
  cover: '',
  publisher: '',
  isbn: '',
  itemId: id,
  link: '',
  description: '',
  pubDate: '',
);
void main() {
  test('a late search response cannot replace a newer query', () async {
    final catalog = ControlledCatalog();
    final container = ProviderContainer(
      overrides: [bookCatalogProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(bookSearchProvider.notifier);
    final first = notifier.search('처음');
    final second = notifier.search('나중');
    catalog.pending['나중:1']!.complete([book(2)]);
    await second;
    catalog.pending['처음:1']!.complete([book(1)]);
    await first;
    expect(container.read(bookSearchProvider).query, '나중');
    expect(container.read(bookSearchProvider).results.single.itemId, 2);
  });
  test('late pagination cannot append to a different search', () async {
    final catalog = ControlledCatalog();
    final container = ProviderContainer(
      overrides: [bookCatalogProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(bookSearchProvider.notifier);
    final first = notifier.search('처음');
    catalog.pending['처음:1']!.complete(List.generate(50, book));
    await first;
    final more = notifier.loadMore();
    final second = notifier.search('나중');
    catalog.pending['나중:1']!.complete([book(100)]);
    await second;
    catalog.pending['처음:2']!.complete([book(51)]);
    await more;
    expect(container.read(bookSearchProvider).results.single.itemId, 100);
    expect(container.read(bookSearchProvider).isLoadingMore, isFalse);
    final third = notifier.search('삭제할 검색');
    notifier.reset();
    catalog.pending['삭제할 검색:1']!.complete([book(200)]);
    await third;
    expect(container.read(bookSearchProvider).query, isEmpty);
    expect(container.read(bookSearchProvider).results, isEmpty);
  });
}
