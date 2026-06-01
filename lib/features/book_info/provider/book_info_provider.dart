import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/model/my_book_detail.dart';
import '../../../features/home/provider/home_provider.dart';
import '../../../features/history/provider/history_provider.dart';
import '../../../shared/widgets/book_edit_bottom_sheet.dart';

class BookInfoState {
  final MyBookDetail? detail;
  final bool isLoading;
  final String? error;

  const BookInfoState({this.detail, this.isLoading = false, this.error});

  BookInfoState copyWith({MyBookDetail? detail, bool? isLoading, String? error}) =>
      BookInfoState(
        detail:    detail    ?? this.detail,
        isLoading: isLoading ?? this.isLoading,
        error:     error,
      );
}

class BookInfoNotifier extends FamilyNotifier<BookInfoState, int> {
  @override
  BookInfoState build(int mybookId) {
    _load(mybookId);
    return const BookInfoState(isLoading: true);
  }

  Future<void> _load(int mybookId) async {
    try {
      final ds = ref.read(myBookDataSourceProvider);
      final detail = await ds.getMyBookDetail(mybookId);
      state = state.copyWith(detail: detail, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> delete(int mybookId) async {
    try {
      await ref.read(myBookDataSourceProvider).deleteMyBook(mybookId);
      ref.read(homeProvider.notifier).load();
      ref.read(historyProvider.notifier).load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateReason(int mybookId, String reason) async {
    return applyEdit(
      mybookId,
      BookEditResult(reason: reason),
    );
  }

  /// `BookEditResult` 를 PATCH 본문으로 변환해 적용한다.
  /// 백엔드 스키마: `shelfType`, `reason`, `historyInfo.{startedDate,finishedDate}`,
  /// `bookInfo.{title,author,publisher,publishDate,isbn,totalPage}`.
  Future<bool> applyEdit(int mybookId, BookEditResult edit) async {
    final body = <String, dynamic>{};
    if (edit.shelfType != null) body['shelfType'] = edit.shelfType;
    if (edit.reason != null) body['reason'] = edit.reason;

    final history = <String, dynamic>{};
    if (edit.startedDate != null) history['startedDate'] = edit.startedDate;
    if (edit.finishedDate != null) history['finishedDate'] = edit.finishedDate;
    if (history.isNotEmpty) body['historyInfo'] = history;

    final bookInfo = <String, dynamic>{};
    if (edit.bookInfoTitle != null) bookInfo['title'] = edit.bookInfoTitle;
    if (edit.bookInfoAuthor != null) bookInfo['author'] = edit.bookInfoAuthor;
    if (edit.bookInfoPublisher != null) {
      bookInfo['publisher'] = edit.bookInfoPublisher;
    }
    if (edit.bookInfoPublishDate != null) {
      bookInfo['publishDate'] = edit.bookInfoPublishDate;
    }
    // Android 원본 키는 대문자 `ISBN`.
    if (edit.bookInfoIsbn != null) bookInfo['ISBN'] = edit.bookInfoIsbn;
    if (edit.bookInfoTotalPage != null) {
      bookInfo['totalPage'] = edit.bookInfoTotalPage;
    }
    if (bookInfo.isNotEmpty) body['bookInfo'] = bookInfo;

    try {
      await ref.read(myBookDataSourceProvider).updateMyBook(mybookId, body);
      // 서버 상태가 진짜 정답이므로 다시 fetch.
      await _load(mybookId);
      ref.read(homeProvider.notifier).load();
      ref.read(historyProvider.notifier).load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bookInfoProvider =
    NotifierProviderFamily<BookInfoNotifier, BookInfoState, int>(BookInfoNotifier.new);
