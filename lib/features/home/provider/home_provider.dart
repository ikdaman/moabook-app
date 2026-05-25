import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasource/mybook_datasource.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/auth/provider/auth_provider.dart';

// ── DataSource Provider ───────────────────────────────────────────────────

final myBookDataSourceProvider = Provider<MyBookDataSource>((ref) {
  return MyBookDataSourceImpl(ref.watch(dioProvider));
});

// ── Home State ────────────────────────────────────────────────────────────

class HomeState {
  final List<StoreBookItem> books;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final bool sortDescending;
  final int currentPage;

  const HomeState({
    this.books        = const [],
    this.isLoading    = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore      = true,
    this.sortDescending = true,
    this.currentPage  = 0,
  });

  HomeState copyWith({
    List<StoreBookItem>? books,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    bool? sortDescending,
    int? currentPage,
  }) => HomeState(
    books:          books          ?? this.books,
    isLoading:      isLoading      ?? this.isLoading,
    isLoadingMore:  isLoadingMore  ?? this.isLoadingMore,
    error:          error,
    hasMore:        hasMore        ?? this.hasMore,
    sortDescending: sortDescending ?? this.sortDescending,
    currentPage:    currentPage    ?? this.currentPage,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class HomeNotifier extends Notifier<HomeState> {
  static const _pageSize = 10;

  @override
  HomeState build() {
    return const HomeState(isLoading: true);
  }

  MyBookDataSource get _ds => ref.read(myBookDataSourceProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, currentPage: 0);
    try {
      final result = await _ds.getStoreBooks(
        page: 0,
        size: _pageSize,
        descending: state.sortDescending,
      );
      state = state.copyWith(
        books:       result.content,
        isLoading:   false,
        hasMore:     !result.last,
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final result   = await _ds.getStoreBooks(
        page:       nextPage,
        size:       _pageSize,
        descending: state.sortDescending,
      );
      state = state.copyWith(
        books:          [...state.books, ...result.content],
        isLoadingMore:  false,
        hasMore:        !result.last,
        currentPage:    nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleSort() async {
    state = state.copyWith(sortDescending: !state.sortDescending);
    await load();
  }

  Future<void> deleteBook(int mybookId) async {
    await _ds.deleteMyBook(mybookId);
    state = state.copyWith(
      books: state.books.where((b) => b.mybookId != mybookId).toList(),
    );
  }

  Future<void> startReading(int mybookId) async {
    await _ds.updateReadingStatus(mybookId, 'READING');
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);
