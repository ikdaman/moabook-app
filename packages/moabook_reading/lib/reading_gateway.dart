import 'dart:typed_data';
import 'moabook_reading.dart';

class ReadingBook {
  const ReadingBook(
    this.id,
    this.title,
    this.author,
    this.publisher,
    this.reason,
    this.reasonType, {
    this.demo = false,
    this.totalPage,
    this.publishDate,
    this.coverUrl,
    this.aladinId,
    this.yes24Id,
    this.isbn13,
    this.link,
  });
  final String id, title, author, publisher, reason, reasonType;
  final bool demo;
  final int? totalPage;
  final String? publishDate, coverUrl, aladinId, yes24Id, isbn13, link;
  String get cover => 'assets/design_preview/covers/$id.jpg';

  /// Partial list/detail responses must not erase a known page count.
  ReadingBook withPageCountFallback(int? previous) {
    if ((totalPage ?? 0) > 0 || (previous ?? 0) <= 0) return this;
    return ReadingBook(
      id,
      title,
      author,
      publisher,
      reason,
      reasonType,
      demo: demo,
      totalPage: previous,
      publishDate: publishDate,
      coverUrl: coverUrl,
      aladinId: aladinId,
      yes24Id: yes24Id,
      isbn13: isbn13,
      link: link,
    );
  }

  ReadingBook withReason(String value) => ReadingBook(
    id,
    title,
    author,
    publisher,
    value,
    '',
    demo: demo,
    totalPage: totalPage,
    publishDate: publishDate,
    coverUrl: coverUrl,
    aladinId: aladinId,
    yes24Id: yes24Id,
    isbn13: isbn13,
    link: link,
  );
}

class ReadingShelf {
  ReadingShelf({required Iterable<ReadingBook> books, required this.totalCount})
    : books = List.unmodifiable(books);
  final List<ReadingBook> books;
  final int totalCount;
}

class ReadingCard {
  const ReadingCard({
    required this.book,
    required this.createdDate,
    required this.status,
    required this.recordCount,
  });
  final ReadingBook book;
  final DateTime createdDate;
  final ReadingCategory? status;
  final int? recordCount;
}

class ReadingCollectionSummary {
  ReadingCollectionSummary({
    required this.id,
    required this.name,
    required Iterable<ReadingBook> representatives,
  }) : representatives = List.unmodifiable(representatives);
  final String id, name;
  final List<ReadingBook> representatives;
}

class ReadingCollectionDetail {
  ReadingCollectionDetail({
    required this.collection,
    required Iterable<ReadingBook> books,
  }) : books = List.unmodifiable(books);
  final ReadingCollection collection;
  final List<ReadingBook> books;
}

/// The live app implements this with its authenticated network client.
/// The offline preview does not silently substitute for a failed gateway.
abstract interface class ReadingGateway {
  Future<ReadingBookCheck> checkBook(ReadingBook book, {String? collectionId});
  Future<String> saveBook(ReadingBook book, {required String reason});
  Future<void> deleteBook(String bookId);
  Future<ReadingShelf> loadShelf();
  Future<ReadingCard> loadCard(String bookId);
  Future<List<ReadingRecord>> loadRecords(String bookId);
  Future<List<ReadingCollectionSummary>> loadCollections();
  Future<ReadingCollectionDetail> loadCollection(String collectionId);
  Future<ReadingCollectionDetail> createCollection(String name);
  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection collection,
  );
  Future<String> addRecord(
    String bookId, {
    required ReadingCategory category,
    required DateTime date,
    required String memo,
  });
  Future<ReadingSearchPage> searchBooks(String keyword, {int page = 1});
}

class ReadingWriteUncertain implements Exception {
  const ReadingWriteUncertain();
}

class CollectionCreatedNeedsReload implements Exception {
  const CollectionCreatedNeedsReload(this.id, this.name);
  final String id, name;
}

class ReadingImageExport {
  ReadingImageExport({
    required this.title,
    required Iterable<ReadingBook> books,
  }) : books = List.unmodifiable(books),
       shelfPages = const [],
       collectionSlots = null,
       collectionPng = null;

  factory ReadingImageExport.collection({
    required String title,
    required Iterable<ReadingBook?> slots,
    Uint8List? png,
  }) {
    final values = List<ReadingBook?>.unmodifiable(slots);
    if (values.length != pageSize) throw ArgumentError('컬렉션은 9칸입니다.');
    return ReadingImageExport._collection(title, values, png);
  }

  ReadingImageExport._collection(
    this.title,
    this.collectionSlots,
    this.collectionPng,
  ) : books = List.unmodifiable(collectionSlots!.whereType<ReadingBook>()),
      shelfPages = const [];

  factory ReadingImageExport.shelf({
    required String title,
    required Iterable<ReadingShelfImage> pages,
  }) {
    final images = List<ReadingShelfImage>.unmodifiable(pages);
    return ReadingImageExport._shelf(title, images);
  }

  ReadingImageExport._shelf(this.title, this.shelfPages)
    : books = List.unmodifiable(shelfPages.expand((page) => page.books)),
      collectionSlots = null,
      collectionPng = null;

  final List<ReadingShelfImage> shelfPages;
  final List<ReadingBook?>? collectionSlots;
  final Uint8List? collectionPng;
  final String title;
  final List<ReadingBook> books;
  static const pageSize = 9;
  int get pageCount => shelfPages.isNotEmpty
      ? shelfPages.length
      : (books.length / pageSize).ceil();
  List<ReadingBook> page(int index) {
    if (index < 0 || index >= pageCount) throw RangeError.index(index, books);
    if (shelfPages.isNotEmpty) return shelfPages[index].books;
    return books.skip(index * pageSize).take(pageSize).toList();
  }
}

class ReadingBookCheck {
  const ReadingBookCheck({
    required this.bookId,
    this.alreadyInCollection = false,
  });
  final String? bookId;
  final bool alreadyInCollection;
}

class ReadingSearchPage {
  ReadingSearchPage({
    required Iterable<ReadingBook> books,
    required this.page,
    required this.hasMore,
    this.totalCount,
  }) : books = List.unmodifiable(books);
  final List<ReadingBook> books;
  final int page;
  final bool hasMore;
  final int? totalCount;
}

/// A rendered page of the basic shelf, retaining its spine layout and book order.
class ReadingShelfImage {
  ReadingShelfImage({required Iterable<ReadingBook> books, required this.png})
    : books = List.unmodifiable(books);
  final List<ReadingBook> books;
  final Uint8List png;
}
