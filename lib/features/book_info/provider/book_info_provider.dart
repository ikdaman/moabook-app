import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/model/my_book_detail.dart';
import '../../../features/home/provider/home_provider.dart';

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
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateReason(int mybookId, String reason) async {
    try {
      await ref.read(myBookDataSourceProvider).updateMyBook(mybookId, {'reason': reason});
      state = state.copyWith(
        detail: state.detail == null
            ? null
            : MyBookDetail(
                mybookId:      state.detail!.mybookId,
                readingStatus: state.detail!.readingStatus,
                createdDate:   state.detail!.createdDate,
                reason:        reason,
                bookInfo:      state.detail!.bookInfo,
                historyInfo:   state.detail!.historyInfo,
              ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bookInfoProvider =
    NotifierProviderFamily<BookInfoNotifier, BookInfoState, int>(BookInfoNotifier.new);
