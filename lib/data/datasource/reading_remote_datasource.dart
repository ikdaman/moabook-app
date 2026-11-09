import 'package:dio/dio.dart';
import 'package:moabook_reading/moabook_reading.dart';
import '../../core/util/date_formatter.dart';
import '../../core/util/html_text.dart';

/// Paths/parameters differ between the published document and server main.
/// Choose explicitly per environment; never probe other endpoints after failure.
class ReadingApiConfig {
  const ReadingApiConfig({
    this.shelfPath = '/mybooks',
    this.pageSizeKey = 'limit',
  });
  final String shelfPath, pageSizeKey;
}

class ReadingRemoteDataSource {
  ReadingRemoteDataSource(this.dio, {this.config = const ReadingApiConfig()});
  final Dio dio;
  final ReadingApiConfig config;
  final Map<String, ReadingBook> _knownCatalogBooks = {};

  Future<ReadingBookCheck> checkBook(
    ReadingBook book, {
    String? collectionId,
  }) async {
    // All current server books use YES24; aladinId is the legacy wire name.
    if (book.yes24Id == null) {
      if (!book.id.contains(':')) {
        final id = _id(book.id);
        if (collectionId == null) return ReadingBookCheck(bookId: id);
        final collection = await loadCollection(collectionId);
        return ReadingBookCheck(
          bookId: id,
          alreadyInCollection: collection.collection.contains(id),
        );
      }
      throw const FormatException('Missing YES24 identity');
    }
    final path = collectionId == null
        ? '/mybooks/check'
        : '/collections/${_id(collectionId)}/books/check';
    final response = await dio.get<Object?>(
      path,
      queryParameters: {'aladinId': int.parse(_id(book.yes24Id))},
    );
    final data = _map(response.data);
    if (!data.containsKey('mybookId')) {
      throw const FormatException('Missing shelf check result');
    }
    final id = data['mybookId'] == null ? null : _id(data['mybookId']);
    if (collectionId != null &&
        (data['onShelf'] is! bool ||
            data['alreadyInCollection'] is! bool ||
            data['onShelf'] != (id != null) ||
            (data['alreadyInCollection'] == true && id == null))) {
      throw const FormatException('Invalid collection check result');
    }
    if (id != null) _knownCatalogBooks[id] = book;
    return ReadingBookCheck(
      bookId: id,
      alreadyInCollection: data['alreadyInCollection'] == true,
    );
  }

  Future<String> saveBook(ReadingBook book, {required String reason}) async {
    if (book.yes24Id == null) {
      throw const FormatException('Missing YES24 identity');
    }
    // Apply the same memo limit before creating any server data.
    ReadingRecord(
      id: 'validation',
      category: ReadingCategory.todo,
      date: DateTime.now(),
      memo: reason,
    );
    try {
      final response = await dio.post<Object?>(
        '/mybooks',
        data: {
          'bookInfo': {
            'aladinId': int.parse(_id(book.yes24Id)),
            'title': book.title,
            'author': book.author,
            'publisher': book.publisher,
            'totalPage': book.totalPage,
            'coverImage': book.coverUrl,
          },
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
      try {
        final id = _id(_map(response.data)['mybookId']);
        _knownCatalogBooks[id] = book;
        return id;
      } on FormatException {
        throw const ReadingWriteUncertain();
      }
    } on DioException catch (error) {
      if (error.response == null || (error.response?.statusCode ?? 0) >= 500) {
        throw const ReadingWriteUncertain();
      }
      rethrow;
    }
  }

  Future<void> deleteBook(String bookId) async {
    await dio.delete<void>('/mybooks/${_id(bookId)}');
    _knownCatalogBooks.remove(bookId);
  }

  Future<ReadingShelf> loadShelf() async {
    final books = <String, ReadingBook>{};
    var totalPages = 1;
    var totalCount = 0;
    for (var page = 0; page < totalPages; page++) {
      final response = await dio.get<Object?>(
        config.shelfPath,
        queryParameters: {'page': page, config.pageSizeKey: 100},
      );
      final data = _map(response.data);
      totalPages = _integer(data['totalPages']);
      totalCount = _integer(data['totalElements']);
      if (totalPages < 0 || totalPages > 1000 || totalCount < 0) {
        throw const FormatException('Invalid shelf pagination');
      }
      final items = _list(data['books']);
      if (page > 0 && items.isEmpty && page < totalPages) {
        throw const FormatException('Incomplete shelf pagination');
      }
      for (final item in items) {
        final book = _book(_map(item));
        books[book.id] = book;
      }
    }
    if (books.length != totalCount) {
      throw const FormatException('Shelf changed while paging');
    }
    return ReadingShelf(books: books.values, totalCount: totalCount);
  }

  Future<ReadingCard> loadCard(String bookId) async {
    final response = await dio.get<Object?>('/mybooks/${_id(bookId)}');
    final data = _map(response.data);
    final book = _book(data, requestedId: bookId);
    final created = DateFormatter.parseToLocal(_text(data['createdDate']));
    if (created == null) {
      throw const FormatException('Missing book creation date');
    }
    final status = data['readingStatus'];
    return ReadingCard(
      book: book,
      createdDate: created,
      status: status == null ? null : _category(status),
      recordCount: data['totalRecords'] == null
          ? null
          : _integer(data['totalRecords']),
    );
  }

  Future<List<ReadingRecord>> loadRecords(String bookId) async {
    final response = await dio.get<Object?>('/mybooks/${_id(bookId)}/records');
    final body = response.data;
    final items = body is List ? body : _list(_map(body)['records']);
    return [for (var i = 0; i < items.length; i++) _record(_map(items[i]), i)];
  }

  Future<String> addRecord(
    String bookId, {
    required ReadingCategory category,
    required DateTime date,
    required String memo,
  }) async {
    // Validate before sending, using the same rules as the form.
    ReadingRecord(id: 'validation', category: category, date: date, memo: memo);
    Response<Object?> response;
    try {
      response = await dio.post<Object?>(
        '/mybooks/${_id(bookId)}/records',
        data: {
          'recordType': category.code,
          // The UI selects a local calendar day; send that instant in UTC.
          'recordDate': readingDay(
            date,
          ).toUtc().toIso8601String().replaceAll('.000Z', 'Z'),
          'memo': memo.trim().isEmpty ? null : memo.trim(),
        },
      );
    } on DioException catch (error) {
      if (error.response == null || (error.response?.statusCode ?? 0) >= 500) {
        throw const ReadingWriteUncertain();
      }
      rethrow;
    }
    try {
      return _id(_map(response.data)['recordId']);
    } on FormatException {
      // A successful write with an unusable response must never be blindly repeated.
      throw const ReadingWriteUncertain();
    }
  }

  Future<List<ReadingCollectionSummary>> loadCollections() async {
    final response = await dio.get<Object?>('/collections');
    return _list(_map(response.data)['collections']).map((item) {
      final data = _map(item);
      return ReadingCollectionSummary(
        id: _id(data['collectionId']),
        name: _requiredText(data['name']),
        representatives: [
          for (final value in _list(data['representativeBooks']))
            ReadingBook(
              _id(_map(value)['mybookId'] ?? _map(value)['myBookId']),
              '',
              '',
              '',
              '',
              '',
              coverUrl: _nullableText(_map(value)['coverImage']),
            ),
        ],
      );
    }).toList();
  }

  Future<ReadingCollectionDetail> loadCollection(String id) async {
    final response = await dio.get<Object?>('/collections/${_id(id)}');
    final result = _collection(_map(response.data));
    if (result.collection.id != id) {
      throw const FormatException(
        'Collection response ID does not match request',
      );
    }
    return result;
  }

  Future<ReadingCollectionDetail> createCollection(String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Collection name is required');
    Response<Object?> response;
    try {
      response = await dio.post<Object?>(
        '/collections',
        data: {'name': name.trim()},
      );
    } on DioException catch (error) {
      if (error.response == null || (error.response?.statusCode ?? 0) >= 500) {
        throw const ReadingWriteUncertain();
      }
      rethrow;
    }
    late Map<String, dynamic> data;
    late String id;
    try {
      data = _map(response.data);
      id = _id(data['collectionId']);
    } on FormatException {
      throw const ReadingWriteUncertain();
    }
    try {
      if (data.containsKey('slots')) return _collection(data);
      return await loadCollection(id);
    } catch (_) {
      throw CollectionCreatedNeedsReload(id, name.trim());
    }
  }

  Future<ReadingCollectionDetail> updateCollection(
    ReadingCollection collection,
  ) async {
    final response = await dio.put<Object?>(
      '/collections/${_id(collection.id)}',
      data: {
        'name': collection.name,
        'books': [
          for (var index = 0; index < 9; index++)
            if (collection.slots[index] != null)
              {
                'mybookId': int.parse(_id(collection.slots[index])),
                'slotNo': index + 1,
              },
        ],
      },
    );
    final result = _collection(_map(response.data));
    if (result.collection.id != collection.id) {
      throw const FormatException(
        'Collection response ID does not match request',
      );
    }
    return result;
  }

  ReadingCollectionDetail _collection(Map<String, dynamic> data) {
    final slots = List<String?>.filled(9, null);
    final seen = <int>{};
    final books = <ReadingBook>[];
    for (final item
        in data['slots'] == null ? const [] : _list(data['slots'])) {
      final slot = _map(item);
      final index = _integer(slot['slotNo']) - 1;
      if (index < 0 || index >= 9 || !seen.add(index)) {
        throw const FormatException('Invalid collection slot');
      }
      if (slot['empty'] == true) continue;
      final book = _book(slot);
      slots[index] = book.id;
      books.add(book);
    }
    return ReadingCollectionDetail(
      collection: ReadingCollection(
        id: _id(data['collectionId']),
        name: _requiredText(data['name']),
        slots: slots,
      ),
      books: books,
    );
  }

  ReadingBook _book(Map<String, dynamic> data, {String? requestedId}) {
    final idValue = data['mybookId'] ?? data['myBookId'] ?? requestedId;
    final id = _id(idValue);
    if (requestedId != null && id != requestedId) {
      throw const FormatException('Book response ID does not match request');
    }
    final info = data['bookInfo'] is Map ? _map(data['bookInfo']) : data;
    final authors = info['author'];
    final known = _knownCatalogBooks[id];
    // Existing Aladin data has been removed; the current contract uses this
    // legacy field for YES24 goods IDs in both catalog and saved-book responses.
    final yes24Id =
        _nullableText(info['yes24Id'] ?? info['aladinId']) ?? known?.yes24Id;
    return ReadingBook(
      id,
      _text(_requiredText(info['title'])),
      authors is List
          ? authors.map((a) => _text(a)).join(', ')
          : _text(authors),
      _text(info['publisher']),
      data['reason']?.toString() ?? '',
      '',
      coverUrl: _nullableText(info['coverImage']),
      totalPage: info['totalPage'] == null ? null : _integer(info['totalPage']),
      publishDate: _nullableText(info['publishDate']),
      yes24Id: yes24Id,
      isbn13: _nullableText(info['isbn13'] ?? info['isbn']),
      link:
          _nullableText(info['link']) ??
          known?.link ??
          (yes24Id == null
              ? null
              : 'https://www.yes24.com/product/goods/${Uri.encodeComponent(yes24Id)}'),
    );
  }

  ReadingRecord _record(Map<String, dynamic> data, int index) {
    final date = DateFormatter.parseToLocal(_text(data['recordDate']));
    if (date == null) throw const FormatException('Invalid record date');
    return ReadingRecord(
      // Some deployed DTOs hide recordId. This key is for display only,
      // never for server mutations or deriving current status.
      id: data['recordId'] == null ? 'display-$index' : _id(data['recordId']),
      category: _category(data['recordType']),
      date: date,
      memo: data['memo']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return value;
  }

  static List<dynamic> _list(Object? value) {
    if (value is! List) throw const FormatException('Expected JSON list');
    return value;
  }

  static String _text(Object? value) =>
      decodeHtmlEntities(value?.toString()) ?? '';
  static String? _nullableText(Object? value) =>
      value == null ? null : _text(value);
  static String _requiredText(Object? value) {
    final result = value?.toString() ?? '';
    if (result.trim().isEmpty) {
      throw const FormatException('Missing required text');
    }
    return result;
  }

  static int _integer(Object? value) {
    final result = int.tryParse(value?.toString() ?? '');
    if (result == null) throw const FormatException('Expected integer');
    return result;
  }

  static String _id(Object? value) {
    final result = _integer(value);
    if (result <= 0) throw const FormatException('Expected positive ID');
    return result.toString();
  }

  static ReadingCategory _category(Object? value) =>
      ReadingCategory.values.firstWhere(
        (category) => category.code == value,
        orElse: () => throw const FormatException('Unknown record category'),
      );
}
