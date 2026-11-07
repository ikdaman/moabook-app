import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/data/datasource/reading_remote_datasource.dart';
import 'package:moabook_reading/moabook_reading.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Map<String, dynamic> book(int id, {Object pages = 128}) => {
  'mybookId': id,
  'reason': '이유',
  'bookInfo': {
    'title': '책 &amp; 제목 $id',
    'author': ['작가'],
    'coverImage': null,
    'totalPage': pages,
  },
};

Map<String, dynamic> collection({String name = '모음'}) => {
  'collectionId': 8,
  'name': name,
  'slots': [
    for (var slot = 1; slot <= 9; slot++)
      {'slotNo': slot, 'empty': slot != 3, if (slot == 3) ...book(7)},
  ],
};

void main() {
  late Dio dio;
  ReadingRemoteDataSource setup(
    ResponseBody Function(RequestOptions) respond, {
    ReadingApiConfig config = const ReadingApiConfig(),
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://development.invalid',
        headers: {'Authorization': 'Bearer test-only'},
      ),
    );
    dio.httpClientAdapter = _Adapter(respond);
    addTearDown(() => dio.close(force: true));
    return ReadingRemoteDataSource(dio, config: config);
  }

  const candidate = ReadingBook(
    'yes24:123',
    '새 책',
    '저자',
    '출판사',
    '',
    '',
    yes24Id: '123',
    totalPage: 192,
    coverUrl: 'https://example.com/cover.jpg',
  );

  test(
    'shelf check sends YES24 goods ID with the documented legacy key',
    () async {
      var existing = false;
      final remote = setup((request) {
        expect(request.method, 'GET');
        expect(request.path, '/mybooks/check');
        expect(request.queryParameters, {'aladinId': 123});
        return jsonBody({'mybookId': existing ? 7 : null});
      });
      expect((await remote.checkBook(candidate)).bookId, isNull);
      existing = true;
      expect((await remote.checkBook(candidate)).bookId, '7');
    },
  );

  test(
    'collection check distinguishes existing shelf and collection books',
    () async {
      var inCollection = false;
      final remote = setup((request) {
        expect(request.path, '/collections/8/books/check');
        expect(request.queryParameters, {'aladinId': 123});
        return jsonBody({
          'onShelf': true,
          'mybookId': 7,
          'alreadyInCollection': inCollection,
        });
      });
      expect(
        (await remote.checkBook(
          candidate,
          collectionId: '8',
        )).alreadyInCollection,
        isFalse,
      );
      inCollection = true;
      final check = await remote.checkBook(candidate, collectionId: '8');
      expect(check.bookId, '7');
      expect(check.alreadyInCollection, isTrue);
    },
  );

  test('malformed check never becomes a new-book decision', () async {
    final remote = setup((_) => jsonBody({'status': 500}));
    await expectLater(remote.checkBook(candidate), throwsFormatException);
  });

  test(
    'save sends current bookInfo only and accepts documented 200 or 201',
    () async {
      var status = 200;
      final remote = setup((request) {
        expect(request.method, 'POST');
        expect(request.path, '/mybooks');
        expect(request.data, {
          'bookInfo': {
            'aladinId': 123,
            'title': '새 책',
            'author': '저자',
            'publisher': '출판사',
            'totalPage': 192,
            'coverImage': 'https://example.com/cover.jpg',
          },
          'reason': '읽고 싶어요',
        });
        return jsonBody({'mybookId': 41}, status: status);
      });
      expect(await remote.saveBook(candidate, reason: ' 읽고 싶어요 '), '41');
      status = 201;
      expect(await remote.saveBook(candidate, reason: '읽고 싶어요'), '41');
    },
  );

  test(
    'successful book write without an ID is uncertain, not retryable rejection',
    () async {
      final remote = setup((_) => jsonBody({}, status: 201));
      await expectLater(
        remote.saveBook(candidate, reason: ''),
        throwsA(isA<ReadingWriteUncertain>()),
      );
      expect((dio.httpClientAdapter as _Adapter).requests.length, 1);
    },
  );

  test(
    'shelf fetches every server page and preserves ID, pages and authorization',
    () async {
      final remote = setup((request) {
        expect(request.path, '/mybooks');
        expect(request.queryParameters['limit'], 100);
        expect(request.headers['Authorization'], 'Bearer test-only');
        final page = request.queryParameters['page'] as int;
        return jsonBody({
          'totalPages': 2,
          'totalElements': 2,
          'books': [book(page + 1, pages: page == 0 ? '192' : 256)],
        });
      });
      final result = await remote.loadShelf();
      expect(result.books.map((b) => b.id), ['1', '2']);
      expect(result.books.first.title, '책 & 제목 1');
      expect(result.books.first.totalPage, 192);
      expect(result.totalCount, 2);
    },
  );

  test(
    'server-main endpoint configuration is explicit and no fallback requests are made',
    () async {
      final remote = setup(
        (request) {
          expect(request.path, '/mybooks');
          expect(request.queryParameters['size'], 100);
          return jsonBody({'totalPages': 0, 'totalElements': 0, 'books': []});
        },
        config: const ReadingApiConfig(
          shelfPath: '/mybooks',
          pageSizeKey: 'size',
        ),
      );
      expect((await remote.loadShelf()).books, isEmpty);
      expect((dio.httpClientAdapter as _Adapter).requests.length, 1);
    },
  );

  test(
    'failed or inconsistent shelf never becomes an empty successful shelf',
    () async {
      final remote = setup(
        (request) => jsonBody({
          'totalPages': 1,
          'totalElements': 2,
          'books': [book(7)],
        }),
      );
      await expectLater(remote.loadShelf(), throwsFormatException);
    },
  );

  test(
    'card parses actual flat metadata and takes current status from the server',
    () async {
      final remote = setup(
        (request) => jsonBody({
          'myBookId': 7,
          'title': '서버 책',
          'author': '작가1, 작가2',
          'publisher': '출판사',
          'coverImage': null,
          'aladinId': '123',
          'reason': '이유',
          'readingStatus': 'DONE',
          'createdDate': '2026-11-01T00:00:00',
          'totalRecords': 3,
        }),
      );
      final card = await remote.loadCard('7');
      expect(card.book.id, '7');
      expect(card.status, ReadingCategory.done);
      expect(card.recordCount, 3);
      expect(card.book.aladinId, isNull);
      expect(card.book.yes24Id, '123');
      expect(card.book.link, 'https://www.yes24.com/product/goods/123');
    },
  );

  test('wrong card ID is rejected instead of showing another book', () async {
    final remote = setup(
      (request) => jsonBody({'mybookId': 9, 'title': '다른 책'}),
    );
    await expectLater(remote.loadCard('7'), throwsFormatException);
  });

  test(
    'record list supports documented array and records wrapper without losing order',
    () async {
      var wrapped = false;
      final remote = setup((request) {
        final records = [
          {
            'recordId': 9,
            'recordType': 'FREE',
            'recordDate': '2026-11-03T00:00:00',
            'memo': '내용 &amp;',
          },
          {
            'recordType': 'DONE',
            'recordDate': '2026-11-01T00:00:00',
            'memo': null,
          },
        ];
        return jsonBody(wrapped ? {'records': records} : records);
      });
      expect((await remote.loadRecords('7')).map((r) => r.category), [
        ReadingCategory.free,
        ReadingCategory.done,
      ]);
      wrapped = true;
      final records = await remote.loadRecords('7');
      expect(records.first.id, '9');
      expect(records.first.memo, '내용 &amp;');
    },
  );

  test(
    'record POST sends real book ID, category, chosen local date as UTC and optional memo',
    () async {
      final day = DateTime(2026, 11, 1);
      final remote = setup((request) {
        expect(request.method, 'POST');
        expect(request.path, '/mybooks/7/records');
        final data = Map<String, dynamic>.from(request.data as Map);
        expect(data['recordType'], 'INPROGRESS');
        expect(DateTime.parse(data['recordDate'] as String).toLocal(), day);
        expect(data['memo'], isNull);
        return jsonBody({'recordId': 42}, status: 201);
      });
      expect(
        await remote.addRecord(
          '7',
          category: ReadingCategory.inProgress,
          date: day,
          memo: '',
        ),
        '42',
      );
    },
  );

  test(
    'FREE validation runs before network; uncertain record responses are not repeated',
    () async {
      final remote = setup((request) => jsonBody({}, status: 201));
      await expectLater(
        remote.addRecord(
          '7',
          category: ReadingCategory.free,
          date: DateTime.now(),
          memo: ' ',
        ),
        throwsArgumentError,
      );
      expect((dio.httpClientAdapter as _Adapter).requests, isEmpty);
      await expectLater(
        remote.addRecord(
          '7',
          category: ReadingCategory.done,
          date: DateTime.now(),
          memo: '',
        ),
        throwsA(isA<ReadingWriteUncertain>()),
      );
      expect((dio.httpClientAdapter as _Adapter).requests.length, 1);
    },
  );

  test(
    'collection slots preserve gaps and PUT sends the entire remaining composition',
    () async {
      final remote = setup((request) {
        if (request.method == 'PUT') {
          final data = Map<String, dynamic>.from(request.data as Map);
          expect(data['name'], '수정');
          expect(data['books'], [
            {'mybookId': 7, 'slotNo': 3},
          ]);
        }
        return jsonBody(
          collection(name: request.method == 'PUT' ? '수정' : '모음'),
        );
      });
      final detail = await remote.loadCollection('8');
      expect(detail.collection.slots[0], isNull);
      expect(detail.collection.slots[2], '7');
      await remote.updateCollection(detail.collection.rename('수정'));
    },
  );

  test(
    'collection create summary is followed by GET; failed GET preserves allocated ID',
    () async {
      final remote = setup(
        (request) => request.method == 'POST'
            ? jsonBody({'collectionId': 8, 'name': '새 모음'}, status: 201)
            : jsonBody({'message': 'unavailable'}, status: 503),
      );
      await expectLater(
        remote.createCollection('새 모음'),
        throwsA(
          isA<CollectionCreatedNeedsReload>().having(
            (error) => error.id,
            'allocated id',
            '8',
          ),
        ),
      );
      expect(
        (dio.httpClientAdapter as _Adapter).requests.map((r) => r.method),
        ['POST', 'GET'],
      );
    },
  );

  test('invalid and duplicate slots are rejected', () async {
    final remote = setup(
      (request) => jsonBody({
        'collectionId': 8,
        'name': '모음',
        'slots': [
          {'slotNo': 1, 'empty': true},
          {'slotNo': 1, 'empty': true},
        ],
      }),
    );
    await expectLater(remote.loadCollection('8'), throwsFormatException);
  });
}
