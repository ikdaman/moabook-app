import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/data/datasource/book_catalog_datasource.dart';
import 'package:moabook/data/datasource/yes24_datasource.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/reading/provider/reading_gateway_provider.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.answer);
  final Object Function(RequestOptions options) answer;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(answer(options)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> envelope({bool success = true, Object? id = 123}) => {
  'success': success,
  'errorCode': success ? null : 'FAILED',
  'data': {
    'items': [
      {
        'itemId': id,
        'title': '제목 &amp; 부제',
        'author': '작가',
        'publisher': '출판사',
        'isbn13': '9788966260959',
        'cover': null,
        'publishDate': '2026-11-01',
        'pages': 192,
      },
    ],
  },
};

void main() {
  late Dio dio;
  late Adapter adapter;
  Yes24DataSource setup(
    Object Function(RequestOptions) answer, {
    String searchPath = '/test/catalog/search',
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://backend.invalid',
        headers: {'Authorization': 'Bearer fixture-only'},
      ),
    );
    adapter = Adapter(answer);
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return Yes24DataSource(
      dio,
      searchPath: searchPath,
      detailPath: '/test/catalog/detail',
    );
  }

  test(
    'search calls configured backend only, retains YES24 identity and pages',
    () async {
      final catalog = setup((request) {
        expect(request.path, '/test/catalog/search');
        expect(request.headers['X-Api-Key'], isNull);
        expect(request.headers['Authorization'], 'Bearer fixture-only');
        expect(request.queryParameters, {
          'query': '책',
          'category': 'BOOK',
          'page': 2,
          'pageSize': 50,
          'detail': 'Y',
        });
        return envelope();
      });
      final item = (await catalog.searchByTitle(' 책 ', page: 2)).single;
      expect(item.source, BookSource.yes24);
      expect(item.title, '제목 & 부제');
      expect(item.totalPage, 192);
      final book = readingBookFromSearch(item);
      expect(book.id, 'yes24:123');
      expect(book.yes24Id, '123');
      expect(book.aladinId, isNull);
      expect(book.isbn13, '9788966260959');
      expect(book.link, 'https://www.yes24.com/product/goods/123');
      expect(item.toSaveRequestBookInfo, throwsStateError);
    },
  );
  test('ISBN lookup uses detail endpoint, not keyword search', () async {
    final catalog = setup((request) {
      expect(request.path, '/test/catalog/detail');
      expect(request.queryParameters['searchType'], 'ISBN13');
      expect(request.queryParameters['query'], '9788966260959');
      return envelope();
    });
    expect((await catalog.searchByIsbn('9788966260959')).single.itemId, 123);
  });
  test(
    'unconfigured proxy never calls the expired provider or guesses an endpoint',
    () async {
      final catalog = setup((_) => envelope(), searchPath: '');
      await expectLater(
        catalog.searchByTitle('책'),
        throwsA(isA<BookCatalogNotReady>()),
      );
      expect(adapter.calls, 0);
    },
  );
  test(
    'external and malformed paths cannot leak backend authorization',
    () async {
      for (final path in [
        'https://apis.yes24.com/v1/goods/itemList',
        '//external.invalid',
        '/\\external.invalid',
      ]) {
        final catalog = setup((_) => envelope(), searchPath: path);
        await expectLater(catalog.searchByTitle('책'), throwsArgumentError);
        expect(adapter.calls, 0);
      }
    },
  );
  test('HTTP 200 error payload remains a failure', () async {
    final catalog = setup((_) => envelope(success: false));
    await expectLater(catalog.searchByTitle('책'), throwsFormatException);
  });
  test(
    'missing identity is rejected; genuine empty result is accepted',
    () async {
      var empty = false;
      final catalog = setup(
        (_) => empty
            ? {
                'success': true,
                'errorCode': null,
                'data': {'items': []},
              }
            : envelope(id: null),
      );
      await expectLater(catalog.searchByTitle('책'), throwsFormatException);
      empty = true;
      expect(await catalog.searchByTitle('책'), isEmpty);
    },
  );
}
