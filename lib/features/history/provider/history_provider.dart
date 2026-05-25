import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/model/my_book_detail.dart';
import '../../../domain/model/login_state.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../features/home/provider/home_provider.dart';

enum HistoryViewType { list, dataset }

class HistoryState {
  final List<HistoryBookInfo> books;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final HistoryViewType viewType;
  final bool sortDescending;
  final int nowPage;
  final bool hasMore;

  const HistoryState({
    this.books          = const [],
    this.isLoading      = false,
    this.isLoadingMore  = false,
    this.error,
    this.viewType       = HistoryViewType.list,
    this.sortDescending = true,
    this.nowPage        = 0,
    this.hasMore        = true,
  });

  HistoryState copyWith({
    List<HistoryBookInfo>? books,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    HistoryViewType? viewType,
    bool? sortDescending,
    int? nowPage,
    bool? hasMore,
  }) => HistoryState(
    books:          books          ?? this.books,
    isLoading:      isLoading      ?? this.isLoading,
    isLoadingMore:  isLoadingMore  ?? this.isLoadingMore,
    error:          error,
    viewType:       viewType       ?? this.viewType,
    sortDescending: sortDescending ?? this.sortDescending,
    nowPage:        nowPage        ?? this.nowPage,
    hasMore:        hasMore        ?? this.hasMore,
  );
}

class HistoryNotifier extends Notifier<HistoryState> {
  static const _pageSize = 20;

  @override
  HistoryState build() {
    ref.listen(loginStateProvider, (prev, next) {
      if (next is LoginInitial) state = const HistoryState();
    });
    ref.listen(isLoggedInProvider, (prev, next) {
      final prevLoggedIn = prev?.valueOrNull;
      final currLoggedIn = next.valueOrNull;
      if (currLoggedIn == false && prevLoggedIn == true) {
        state = const HistoryState();
      } else if (currLoggedIn == true && prevLoggedIn == false) {
        load();
      }
    });

    Future.microtask(() {
      if (ref.read(isLoggedInProvider).valueOrNull == true) {
        load();
      } else {
        ref.read(isLoggedInProvider.future).then((loggedIn) {
          if (loggedIn) load();
        });
      }
    });

    return const HistoryState(isLoading: true);
  }

  Future<void> load() async {
    if (ref.read(isLoggedInProvider).valueOrNull != true) {
      state = const HistoryState();
      return;
    }
    state = state.copyWith(isLoading: true, nowPage: 0);
    try {
      final books = await ref.read(myBookDataSourceProvider).getHistoryBooks(
            page: 0,
            size: _pageSize,
            descending: state.sortDescending,
          );
      state = state.copyWith(
        books:     books,
        isLoading: false,
        nowPage:   0,
        hasMore:   books.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.nowPage + 1;
      final more = await ref.read(myBookDataSourceProvider).getHistoryBooks(
            page: nextPage,
            size: _pageSize,
            descending: state.sortDescending,
          );
      state = state.copyWith(
        books:         [...state.books, ...more],
        isLoadingMore: false,
        nowPage:       nextPage,
        hasMore:       more.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void toggleViewType() {
    state = state.copyWith(
      viewType: state.viewType == HistoryViewType.list
          ? HistoryViewType.dataset
          : HistoryViewType.list,
    );
  }

  Future<void> toggleSort() async {
    state = state.copyWith(sortDescending: !state.sortDescending);
    await load();
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
