import 'package:dio/dio.dart';
import '../../core/util/html_text.dart';
import '../../domain/model/book_item.dart';

class AladinDataSource {
  static const _baseUrl = 'https://www.aladin.co.kr';
  static const _ttbKey  = 'ttbgju060611831003';

  final Dio _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  Future<List<BookItem>> searchByTitle(String query, {int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/ttb/api/ItemSearch.aspx',
      queryParameters: {
        'ttbkey':    _ttbKey,
        'query':     query,
        'queryType': 'Title',
        'cover':     'Big',
        'output':    'js',
        'version':   '20131101',
        'maxResults': 50,
        'start':     page,
      },
    );
    return _parseItems(response.data);
  }

  Future<List<BookItem>> searchByIsbn(String isbn) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/ttb/api/ItemLookUp.aspx',
      queryParameters: {
        'ttbkey':    _ttbKey,
        'ItemId':    isbn,
        'itemIdType': 'ISBN13',
        'cover':     'Big',
        'output':    'js',
        'Version':   '20131101',
      },
    );
    return _parseItems(response.data);
  }

  List<BookItem> _parseItems(Map<String, dynamic>? data) {
    if (data == null) return [];
    final items = data['item'] as List<dynamic>? ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      final subInfo = m['subInfo'] as Map<String, dynamic>?;
      final pageStr = subInfo?['itemPage']?.toString();
      return BookItem(
        title:       decodeHtmlEntities(m['title']       as String?) ?? '',
        author:      decodeHtmlEntities(m['author']      as String?) ?? '',
        cover:       m['cover']     as String? ?? '',
        publisher:   decodeHtmlEntities(m['publisher']   as String?) ?? '',
        isbn:        m['isbn13']    as String? ?? m['isbn'] as String? ?? '',
        itemId:      (m['itemId'] as num?)?.toInt() ?? 0,
        link:        m['link']      as String? ?? '',
        description: decodeHtmlEntities(m['description'] as String?) ?? '',
        pubDate:     m['pubDate']   as String? ?? '',
        totalPage:   pageStr != null ? int.tryParse(pageStr) : null,
      );
    }).toList();
  }
}
