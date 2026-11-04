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
