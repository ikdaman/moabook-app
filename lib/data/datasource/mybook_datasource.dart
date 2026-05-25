import 'package:dio/dio.dart';
import '../../domain/model/store_book.dart';

abstract interface class MyBookDataSource {
  Future<StoreBook> getStoreBooks({
    String? keyword,
    int page = 0,
    int size = 10,
    bool descending = true,
  });

  Future<void> deleteMyBook(int mybookId);

  Future<void> updateReadingStatus(int mybookId, String status);

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
    final response = await _dio.get<Map<String, dynamic>>(
      '/mybooks/store',
      queryParameters: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'size': size,
        'sort': descending ? 'createdDate,desc' : 'createdDate,asc',
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
  Future<void> updateReadingStatus(int mybookId, String status) async {
    await _dio.patch<void>(
      '/mybooks/$mybookId/reading-status',
      data: {'readingStatus': status},
    );
  }

  @override
  Future<void> saveMyBook(Map<String, dynamic> request) async {
    await _dio.post<void>('/mybooks', data: request);
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
      title:       bookInfo['title']       as String? ?? '',
      author:      authorList,
      coverImage:  bookInfo['coverImage']  as String?,
      description: bookInfo['description'] as String?,
      reason:      e['reason']             as String?,
    );
  }
}
