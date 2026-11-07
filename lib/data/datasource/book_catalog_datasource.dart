import '../../domain/model/book_item.dart';

abstract interface class BookCatalogDataSource {
  Future<List<BookItem>> searchByTitle(
    String query, {
    int page = 1,
    bool byKeyword = false,
  });
  Future<List<BookItem>> searchByIsbn(String isbn);
}

class BookCatalogNotReady implements Exception {
  const BookCatalogNotReady();
  @override
  String toString() => '도서 검색을 준비하고 있어요. 잠시 후 다시 시도해주세요.';
}

/// Catalogs which publish real page metadata instead of inferring it from length.
abstract interface class PagedBookCatalogDataSource
    implements BookCatalogDataSource {
  Future<BookCatalogPage> searchPage(String query, {int page = 1});
}

class BookCatalogPage {
  BookCatalogPage({
    required Iterable<BookItem> books,
    required this.page,
    required this.totalPages,
    required this.totalCount,
  }) : books = List.unmodifiable(books);
  final List<BookItem> books;
  final int page, totalPages, totalCount;
  bool get hasMore => page < totalPages;
}
