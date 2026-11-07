import 'package:dio/dio.dart';
import '../../core/util/html_text.dart';
import '../../core/util/isbn.dart';
import '../../domain/model/book_item.dart';
import 'book_catalog_datasource.dart';

/// Backend catalog contract. Its legacy `aladinId` field contains a YES24 ID.
/// Keep the provider identity separate inside the app.
class Yes24DataSource implements PagedBookCatalogDataSource {
  Yes24DataSource(
    this.dio, {
    required this.searchPath,
    required this.detailPath,
  });
  final Dio dio;
  final String searchPath, detailPath;

  @override
  Future<List<BookItem>> searchByTitle(
    String query, {
    int page = 1,
    bool byKeyword = false,
  }) async => (await searchPage(query, page: page)).books;

  @override
  Future<BookCatalogPage> searchPage(String query, {int page = 1}) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    if (query.trim().isEmpty) {
      return BookCatalogPage(
        books: [],
        page: page,
        totalPages: 0,
        totalCount: 0,
      );
    }
    final body = await _request(searchPath, {
      'query': query.trim(),
      'page': page,
      'pageSize': 50,
    });
    if (body == null) {
      return BookCatalogPage(
        books: [],
        page: page,
        totalPages: 0,
        totalCount: 0,
      );
    }
    final books = _books(body);
    int integer(String field) {
      final value = body is Map ? body[field] : null;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed == null || parsed < 0) {
        throw const FormatException('Invalid catalog pagination');
      }
      return parsed;
    }

    final currentPage = integer('nowPage');
    final totalPages = integer('totalPages');
    // The published table misspells totalElements; prefer the actual server key.
    final totalCount = integer(
      body is Map && body.containsKey('totalElements')
          ? 'totalElements'
          : 'totlaElements',
    );
    if (currentPage != page ||
        books.length > totalCount ||
        (books.isNotEmpty && (page > totalPages || totalCount == 0))) {
      throw const FormatException('Inconsistent catalog pagination');
    }
    return BookCatalogPage(
      books: books,
      page: page,
      totalPages: totalPages,
      totalCount: totalCount,
    );
  }

  @override
  Future<List<BookItem>> searchByIsbn(String isbn) async {
    if (!isBookIsbn13(isbn)) {
      throw ArgumentError('ISBN13 required');
    }
    final body = await _request(detailPath, {
      'searchType': 'ISBN13',
      'query': isbn,
    });
    if (body == null) return [];
    // Detail returns one object and omits ISBN, so retain the scanned value.
    return [_book(body, isbn: isbn)];
  }

  Future<Object?> _request(String path, Map<String, Object> query) async {
    // Relative paths only: the authenticated app client must not send its token
    // to YES24 or another host. No guessed proxy endpoint or fallback provider.
    if (path.isEmpty) throw const BookCatalogNotReady();
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('?') ||
        path.contains('#') ||
        path.contains('\\')) {
      throw ArgumentError('A backend-relative catalog path is required');
    }
    final response = await dio.get<Object?>(path, queryParameters: query);
    return response.data;
  }

  List<BookItem> _books(Object? body) {
    if (body is! Map<String, dynamic> || body['books'] is! List) {
      throw const FormatException('Missing catalog books');
    }
    return [for (final raw in body['books'] as List) _book(raw)];
  }

  BookItem _book(Object? raw, {String? isbn}) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid catalog book');
    }
    final id = int.tryParse(raw['aladinId']?.toString() ?? '');
    final title = text(raw['title']);
    if (id == null || id <= 0 || title.trim().isEmpty) {
      throw const FormatException('Missing YES24 book identity');
    }
    return BookItem(
      source: BookSource.yes24,
      itemId: id,
      title: title,
      author: text(raw['author']),
      publisher: text(raw['publisher']),
      cover: text(raw['coverImage']),
      isbn: isbn ?? text(raw['isbn13']),
      link: 'https://www.yes24.com/product/goods/$id',
      description: text(raw['description']),
      pubDate: text(raw['PublishDate'] ?? raw['publishDate']),
      totalPage: int.tryParse(
        (raw['totalPages'] ?? raw['totalPage'])?.toString() ?? '',
      ),
    );
  }

  static String text(Object? value) =>
      decodeHtmlEntities(value?.toString()) ?? '';
}
