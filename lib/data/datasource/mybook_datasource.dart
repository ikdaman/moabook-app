import 'package:dio/dio.dart';
import '../../core/util/html_text.dart';
import '../../domain/model/my_book_detail.dart';
import '../../domain/model/store_book.dart';

abstract interface class MyBookDataSource {
  Future<StoreBook> getStoreBooks({
    String? keyword,
    int page = 0,
    int size = 10,
    bool descending = true,
  });

  Future<MyBookDetail> getMyBookDetail(int mybookId);

  Future<List<StoreBookItem>> searchMyBooks(String query, {int page = 0, int size = 20});

  Future<List<HistoryBookInfo>> getHistoryBooks({int page = 0, int size = 20, bool descending = true});

  Future<void> deleteMyBook(int mybookId);

  /// Android 원본 PATCH `/mybooks/{id}/reading-status` 와 동일하게
  /// `{startedDate, finishedDate}` 본문을 전송한다.
  Future<void> updateReadingStatus(
    int mybookId, {
    String? startedDate,
    String? finishedDate,
  });

  Future<void> updateMyBook(int mybookId, Map<String, dynamic> data);

  Future<void> saveMyBook(Map<String, dynamic> request);
}

class MyBookDataSourceImpl implements MyBookDataSource {
  final Dio _dio;

  MyBookDataSourceImpl(this._dio);

  @override
  Future<StoreBook> getStoreBooks({
    String? keyword,
    int page = 0,
    int size = 10,
    bool descending = true,
  }) async {
    // sort 파라미터는 쉼표 포함 → Dio의 queryParameters에 넣으면 %2C로 인코딩됨
    // 원본 Android: @Query("sort", encoded = true) — path에 직접 포함해 인코딩 우회
    // 서버 JPA 엔티티 필드명 기준: createdAt (JSON 응답의 createdDate와 다름)
    final sortVal = descending ? 'createdAt,desc' : 'createdAt,asc';
    final response = await _dio.get<Map<String, dynamic>>(
      '/mybooks/store?sort=$sortVal',
      queryParameters: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'size': size,
      },
    );
    final data = response.data!;
    final books = (data['books'] as List<dynamic>? ?? [])
        .map((e) => _parseStoreBookItem(e as Map<String, dynamic>))
        .toList();
    final totalPages    = data['totalPages'] as int? ?? 1;
    final nowPage       = data['nowPage']    as int? ?? 0;
    final totalElements = data['totalElements'] as int? ?? 0;

    return StoreBook(
      content:       books,
      totalPages:    totalPages,
      totalElements: totalElements,
      last:          nowPage >= totalPages - 1,
      first:         nowPage == 0,
      number:        nowPage,
      empty:         books.isEmpty,
    );
  }

  @override
  Future<void> deleteMyBook(int mybookId) async {
    await _dio.delete<void>('/mybooks/$mybookId');
  }

  @override
  Future<void> updateReadingStatus(
    int mybookId, {
    String? startedDate,
    String? finishedDate,
  }) async {
    await _dio.patch<void>(
      '/mybooks/$mybookId/reading-status',
      data: {
        'startedDate': startedDate,
        'finishedDate': finishedDate,
      },
    );
  }

  @override
  Future<void> saveMyBook(Map<String, dynamic> request) async {
    await _dio.post<void>('/mybooks', data: request);
  }

  @override
  Future<MyBookDetail> getMyBookDetail(int mybookId) async {
    final r = await _dio.get<Map<String, dynamic>>('/mybooks/$mybookId');
    final d = r.data!;
    final b = d['bookInfo'] as Map<String, dynamic>? ?? {};
    final h = d['historyInfo'] as Map<String, dynamic>? ?? {};
    return MyBookDetail(
      mybookId:      d['mybookId']?.toString() ?? '',
      readingStatus: d['readingStatus'] as String? ?? '',
      shelfType:     d['shelfType']     as String?,
      createdDate:   d['createdDate']   as String? ?? '',
      reason:        d['reason']        as String?,
      bookInfo: MyBookDetailInfo(
        title:       decodeHtmlEntities(b['title']     as String?) ?? '',
        author:      decodeHtmlEntities(b['author']    as String?) ?? '',
        coverImage:  b['coverImage']  as String?,
        publisher:   decodeHtmlEntities(b['publisher'] as String?),
        totalPage:   (b['totalPage']  as num?)?.toInt(),
        publishDate: b['publishDate'] as String?,
        isbn:        b['isbn']        as String?,
        description: decodeHtmlEntities(b['description'] as String?),
        aladinId:    b['aladinId']?.toString(),
        source:      b['source']      as String?,
      ),
      historyInfo: MyBookDetailHistory(
        startedDate:  h['startedDate']  as String?,
        finishedDate: h['finishedDate'] as String?,
      ),
    );
  }

  @override
  Future<List<StoreBookItem>> searchMyBooks(String query, {int page = 0, int size = 20}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/mybooks',
      queryParameters: {'query': query, 'page': page, 'size': size},
    );
    final books = r.data?['books'] as List<dynamic>? ?? [];
    return books.map((e) {
      final m = e as Map<String, dynamic>;
      final b = m['bookInfo'] as Map<String, dynamic>? ?? {};
      final authorRaw = b['author'];
      final List<String> authorList = authorRaw is List
          ? authorRaw.map((a) => a.toString()).toList()
          : authorRaw is String ? [authorRaw] : [];
      return StoreBookItem(
        mybookId:      m['mybookId']      as int,
        createdDate:   m['createdDate']   as String? ?? '',
        readingStatus: m['readingStatus'] as String?,
        title:         decodeHtmlEntities(b['title'] as String?) ?? '',
        author:        authorList.map((a) => decodeHtmlEntities(a) ?? '').toList(),
        coverImage:    b['coverImage']    as String?,
        description:   decodeHtmlEntities(b['description'] as String?),
        reason:        null,
      );
    }).toList();
  }

  @override
  Future<List<HistoryBookInfo>> getHistoryBooks({int page = 0, int size = 20, bool descending = true}) async {
    final sortVal = descending ? 'createdAt,desc' : 'createdAt,asc';
    final r = await _dio.get<Map<String, dynamic>>(
      '/mybooks/history?sort=$sortVal',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    final books = r.data?['books'] as List<dynamic>? ?? [];
    return books.map((e) {
      final m = e as Map<String, dynamic>;
      final b = m['bookInfo'] as Map<String, dynamic>? ?? {};
      final authorRaw = b['author'];
      final List<String> authorList = authorRaw is List
          ? authorRaw.map((a) => a.toString()).toList()
          : authorRaw is String ? [authorRaw] : [];
      return HistoryBookInfo(
        mybookId:     m['mybookId']     as int,
        title:        decodeHtmlEntities(b['title'] as String?) ?? '',
        author:       authorList.map((a) => decodeHtmlEntities(a) ?? '').toList(),
        coverImage:   b['coverImage']   as String?,
        description:  decodeHtmlEntities(b['description'] as String?),
        startedDate:  m['startedDate']  as String? ?? '',
        finishedDate: m['finishedDate'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> updateMyBook(int mybookId, Map<String, dynamic> data) async {
    await _dio.patch<void>('/mybooks/$mybookId', data: data);
  }

  StoreBookItem _parseStoreBookItem(Map<String, dynamic> e) {
    final bookInfo = e['bookInfo'] as Map<String, dynamic>? ?? {};
    final authorRaw = bookInfo['author'];
    final List<String> authorList;
    if (authorRaw is List) {
      authorList = authorRaw.map((a) => a.toString()).toList();
    } else if (authorRaw is String) {
      authorList = [authorRaw];
    } else {
      authorList = [];
    }
    return StoreBookItem(
      mybookId:    e['mybookId']    as int,
      createdDate: e['createdDate'] as String? ?? '',
      title:       decodeHtmlEntities(bookInfo['title'] as String?) ?? '',
      author:      authorList.map((a) => decodeHtmlEntities(a) ?? '').toList(),
      coverImage:  bookInfo['coverImage']  as String?,
      description: decodeHtmlEntities(bookInfo['description'] as String?),
      reason:      e['reason']             as String?,
    );
  }
}
