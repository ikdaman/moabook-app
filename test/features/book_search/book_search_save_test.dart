import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/book_search/provider/book_search_provider.dart';

class SaveAdapter implements HttpClientAdapter {
  int bookPosts = 0, recordPosts = 0;
  int recordStatus = 201;
  int? savedId;
  Map<String, dynamic>? record;
  bool loseBookResponse = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    Object? result;
    var status = 200;
    switch ('${request.method} ${request.path}') {
      case 'GET /mybooks/check':
        expect(request.queryParameters, {'aladinId': 123});
        result = {'mybookId': savedId};
      case 'POST /mybooks':
        bookPosts++;
        savedId = 41;
        expect((request.data as Map).containsKey('historyInfo'), isFalse);
        expect(request.data['bookInfo']['aladinId'], 123);
        if (request.data['reason'] != null) {
          expect(request.data['reason'], '읽고 싶은 이유');
        }
        expect(request.data['bookInfo'].containsKey('source'), isFalse);
        if (loseBookResponse) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        result = {'mybookId': savedId};
        status = 201;
      case 'GET /mybooks/41/records':
        result = record == null ? [] : [record];
      case 'POST /mybooks/41/records':
        recordPosts++;
        status = recordStatus;
        if (status == 201) {
          record = {'recordId': 7, ...request.data as Map<String, dynamic>};
          result = {'recordId': 7};
        } else {
          result = {'status': status};
        }
      default:
        throw StateError(
          'Unexpected request ${request.method} ${request.path}',
        );
    }
    return ResponseBody.fromString(
      jsonEncode(result),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const candidate = BookItem(
  source: BookSource.yes24,
  title: '새 책',
  author: '작가',
  publisher: '출판사',
  cover: '',
  isbn: '',
  itemId: 123,
  link: 'https://www.yes24.com/product/goods/123',
  description: '',
  pubDate: '',
);

void main() {
  late SaveAdapter adapter;
  late ProviderContainer container;
  late BookSearchNotifier notifier;
  setUp(() {
    adapter = SaveAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'))
      ..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    notifier = container.read(bookSearchProvider.notifier);
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
  });

  test(
    'onboarding saves only the book and its reason without creating a record',
    () async {
      expect(
        await notifier.saveBook(book: candidate, reason: '읽고 싶은 이유'),
        isTrue,
      );
      expect(adapter.bookPosts, 1);
      expect(adapter.recordPosts, 0);
      expect(adapter.record, isNull);
      expect(container.read(bookSearchProvider).isSaving, isFalse);
    },
  );

  test('reading dates do not silently create an initial record', () async {
    expect(
      await notifier.saveBook(
        book: candidate,
        finishedDate: '2026-10-03T00:00:00Z',
      ),
      isTrue,
    );
    expect(adapter.bookPosts, 1);
    expect(adapter.recordPosts, 0);
  });

  test(
    'book save completes even when record endpoints are unavailable',
    () async {
      adapter.recordStatus = 500;
      expect(await notifier.saveBook(book: candidate), isTrue);
      expect(adapter.bookPosts, 1);
      expect(adapter.recordPosts, 0);
    },
  );

  test(
    'lost book response is confirmed through duplicate lookup without a second write',
    () async {
      adapter.loseBookResponse = true;
      expect(await notifier.saveBook(book: candidate), isFalse);
      expect(await notifier.saveBook(book: candidate), isTrue);
      expect(adapter.bookPosts, 1);
      expect(adapter.recordPosts, 0);
    },
  );

  test(
    'existing shelf book is reused without creating a book or record',
    () async {
      adapter.savedId = 41;
      expect(await notifier.saveBook(book: candidate), isTrue);
      expect(adapter.bookPosts, 0);
      expect(adapter.recordPosts, 0);
    },
  );
}
