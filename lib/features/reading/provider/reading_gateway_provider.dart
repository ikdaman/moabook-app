import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moabook_reading/moabook_reading.dart';
import '../../../core/env/env.dart';
import '../../../data/datasource/aladin_datasource.dart';
import '../../../data/datasource/reading_remote_datasource.dart';
import '../../../domain/model/book_item.dart';
import '../../auth/provider/auth_provider.dart';

final readingRefreshProvider = StateProvider<int>((ref) => 0);

final readingGatewayProvider = Provider<ReadingGateway>(
  (ref) => AppReadingGateway(
    ReadingRemoteDataSource(
      ref.watch(dioProvider),
      config: const ReadingApiConfig(
        shelfPath: Env.readingShelfPath,
        pageSizeKey: Env.readingPageSizeKey,
      ),
    ),
    AladinDataSource(),
  ),
);

ReadingBook readingBookFromSearch(BookItem item) => ReadingBook(
  'aladin:${item.itemId}',
  item.title,
  item.author,
  item.publisher,
  '',
  '',
  coverUrl: item.cover,
  totalPage: item.totalPage,
  publishDate: item.pubDate,
  aladinId: item.itemId.toString(),
  link: item.link,
);

class AppReadingGateway implements ReadingGateway {
  AppReadingGateway(this.remote, this.aladin);
  final ReadingRemoteDataSource remote;
  final AladinDataSource aladin;
  @override
  Future<ReadingShelf> loadShelf() => remote.loadShelf();
  @override
  Future<ReadingCard> loadCard(String bookId) => remote.loadCard(bookId);
  @override
  Future<List<ReadingRecord>> loadRecords(String bookId) =>
      remote.loadRecords(bookId);
  @override
  Future<List<ReadingCollectionSummary>> loadCollections() =>
      remote.loadCollections();
  @override
  Future<ReadingCollectionDetail> loadCollection(String id) =>
      remote.loadCollection(id);
  @override
  Future<ReadingCollectionDetail> createCollection(String name) =>
      remote.createCollection(name);
  @override
  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection collection,
  ) => remote.updateCollection(collection);
  @override
  Future<String> addRecord(
    String bookId, {
    required ReadingCategory category,
    required DateTime date,
    required String memo,
  }) => remote.addRecord(bookId, category: category, date: date, memo: memo);
  @override
  Future<List<ReadingBook>> searchBooks(String keyword) async =>
      (await aladin.searchByTitle(
        keyword,
        byKeyword: true,
      )).where((item) => item.itemId > 0).map(readingBookFromSearch).toList();
}
