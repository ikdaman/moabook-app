import 'package:dio/dio.dart';
import '../../core/util/html_text.dart';
import '../../domain/model/book_item.dart';
import 'book_catalog_datasource.dart';

/// The backend must forward the YES24 response. API keys stay on that server.
/// Paths are intentionally unset until its published contract is available.
class Yes24DataSource implements BookCatalogDataSource {
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
  }) async {
    if (query.trim().isEmpty) return [];
    if (page < 1) throw ArgumentError.value(page, 'page');
    return _get(searchPath, {
      'query': query.trim(),
      'category': 'BOOK',
      'page': page,
      'pageSize': 50,
      'detail': 'Y',
    });
  }

  @override
  Future<List<BookItem>> searchByIsbn(String isbn) async {
    if (!RegExp(r'^\d{13}$').hasMatch(isbn)) {
      throw ArgumentError('ISBN13 required');
    }
    return _get(detailPath, {
      'query': isbn,
      'searchType': 'ISBN13',
      'detail': 'Y',
    });
  }

  Future<List<BookItem>> _get(String path, Map<String, Object> query) async {
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
    final body = response.data;
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['errorCode'] != null) {
      throw const FormatException('YES24 catalog request failed');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const FormatException('Missing YES24 items');
    }
    return [for (final raw in data['items'] as List) _book(raw)];
  }

  BookItem _book(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid YES24 item');
    }
    final id = int.tryParse(raw['itemId']?.toString() ?? '');
    final title = text(raw['title']);
    if (id == null || id <= 0 || title.trim().isEmpty) {
      throw const FormatException('Missing YES24 book identity');
    }
    final content = raw['contentDetail'];
    return BookItem(
      source: BookSource.yes24,
      itemId: id,
      title: title,
      author: text(raw['author']),
      publisher: text(raw['publisher']),
      cover: text(raw['cover']),
      isbn: text(raw['isbn13']),
      link: text(raw['link']).isEmpty
          ? 'https://www.yes24.com/product/goods/$id'
          : text(raw['link']),
      description: content is Map ? text(content['bookIntroduction']) : '',
      pubDate: text(raw['publishDate']),
      totalPage: int.tryParse(raw['pages']?.toString() ?? ''),
    );
  }

  static String text(Object? value) =>
      decodeHtmlEntities(value?.toString()) ?? '';
}
