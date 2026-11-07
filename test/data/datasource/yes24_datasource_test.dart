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
  final Object? Function(RequestOptions options) answer;
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

Map<String, Object?> envelope({bool success = true, Object? id = 123}) =>
    success
    ? {
        'totalPages': 1,
        'nowPage': 1,
        'totalElements': 1,
        'books': [
          {
            'aladinId': id,
            'title': '제목 &amp; 부제',
            'author': '작가',
            'publisher': '출판사',
            'coverImage': null,
            'PublishDate': '2026-11-01',
            'totalPages': 192,
          },
        ],
      }
    : {'status': 500, 'message': 'failed'};

void main() {
  late Dio dio;
  late Adapter adapter;
  Yes24DataSource setup(
    Object? Function(RequestOptions) answer, {
    String searchPath = '/test/catalog/search',
    String detailPath = '/books/detail',
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
    return Yes24DataSource(dio, searchPath: searchPath, detailPath: detailPath);
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
          'page': 2,
          'pageSize': 50,
        });
        return {
          ...envelope(),
          'nowPage': 2,
          'totalPages': 3,
          'totalElements': 101,
        };
      });
      final item = (await catalog.searchByTitle(' 책 ', page: 2)).single;
      expect(item.source, BookSource.yes24);
      expect(item.title, '제목 & 부제');
      expect(item.totalPage, 192);
      final book = readingBookFromSearch(item);
      expect(book.id, 'yes24:123');
      expect(book.yes24Id, '123');
      expect(book.aladinId, isNull);
      expect(book.isbn13, isEmpty);
      expect(book.link, 'https://www.yes24.com/product/goods/123');
      expect(item.toSaveRequestBookInfo()['aladinId'], 123);
      expect(item.toSaveRequestBookInfo().containsKey('source'), isFalse);
    },
  );
  test('page metadata controls continuation even on a short page', () async {
    final catalog = setup(
      (request) => {
        ...envelope(),
        'totalPages': 3,
        'nowPage': request.queryParameters['page'],
        'totalElements': 3,
      },
    );
    final first = await catalog.searchPage('책');
    expect(first.books.length, 1);
    expect(first.totalCount, 3);
    expect(first.hasMore, isTrue);
    expect((await catalog.searchPage('책', page: 3)).hasMore, isFalse);
  });
  test('wrong page metadata fails without advancing pagination', () async {
    final catalog = setup((_) => envelope());
    await expectLater(catalog.searchPage('책', page: 2), throwsFormatException);
  });
  test('null search result is a completed empty page', () async {
    final catalog = setup((_) => null);
    final page = await catalog.searchPage('없음');
    expect(page.books, isEmpty);
    expect(page.totalCount, 0);
    expect(page.hasMore, isFalse);
  });
  test('unconfigured ISBN endpoint sends no request', () async {
    final catalog = setup((_) => envelope(), detailPath: '');
    await expectLater(
      catalog.searchByIsbn('9788966260959'),
      throwsA(isA<BookCatalogNotReady>()),
    );
    expect(adapter.calls, 0);
  });
  test('ISBN detail maps a single book and retains the scanned ISBN', () async {
    final catalog = setup((request) {
      expect(request.path, '/test/catalog/detail');
      expect(request.queryParameters, {
        'searchType': 'ISBN13',
        'query': '9788925588735',
      });
      expect(request.headers['Authorization'], 'Bearer fixture-only');
      return {
        'aladinId': 101375755,
        'title': '프로젝트 헤일메리',
        'author': '앤디 위어 저/강동혁 역',
        'publisher': '알에이치코리아(RHK)',
        'totalPages': 692,
        'coverImage': 'https://image.yes24.com/goods/101375755/L',
        'publishDate': '2026-02-19',
        'link': 'https://www.yes24.com/product/goods/101375755',
      };
    }, detailPath: '/test/catalog/detail');
    final book = (await catalog.searchByIsbn('9788925588735')).single;
    expect(book.source, BookSource.yes24);
    expect(book.itemId, 101375755);
    expect(book.isbn, '9788925588735');
    expect(book.title, '프로젝트 헤일메리');
    expect(book.author, '앤디 위어 저/강동혁 역');
    expect(book.publisher, '알에이치코리아(RHK)');
    expect(book.totalPage, 692);
    expect(book.pubDate, '2026-02-19');
    expect(book.cover, 'https://image.yes24.com/goods/101375755/L');
    expect(book.link, 'https://www.yes24.com/product/goods/101375755');
    expect(book.toSaveRequestBookInfo()['aladinId'], 101375755);
  });
  test('invalid ISBN is rejected before requesting detail', () async {
    final catalog = setup((_) => null);
    for (final isbn in ['9788925588734', '1234567890128', '']) {
      await expectLater(catalog.searchByIsbn(isbn), throwsArgumentError);
    }
    expect(adapter.calls, 0);
  });
  test(
    'null ISBN detail is empty; malformed and error payloads fail',
    () async {
      Object? body;
      final catalog = setup((_) => body);
      expect(await catalog.searchByIsbn('9788925588735'), isEmpty);
      for (final invalid in [
        envelope(success: false),
        {'title': 'ID 없음'},
        envelope(),
        [],
      ]) {
        body = invalid;
        await expectLater(
          catalog.searchByIsbn('9788925588735'),
          throwsFormatException,
        );
      }
    },
  );
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
      final catalog = setup((_) => empty ? null : envelope(id: null));
      await expectLater(catalog.searchByTitle('책'), throwsFormatException);
      empty = true;
      expect(await catalog.searchByTitle('책'), isEmpty);
    },
  );
}
