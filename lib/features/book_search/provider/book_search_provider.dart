import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasource/aladin_datasource.dart';
import '../../../data/datasource/mybook_datasource.dart';
import '../../../domain/model/book_item.dart';
import '../../../features/home/provider/home_provider.dart';

final aladinDataSourceProvider = Provider((_) => AladinDataSource());

// ── Search State ──────────────────────────────────────────────────────────

class BookSearchState {
  final List<BookItem> results;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final String query;
  final int currentPage;
  final BookItem? selectedBook;
  final bool isSaving;

  const BookSearchState({
    this.results      = const [],
    this.isLoading    = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore      = false,
    this.query        = '',
    this.currentPage  = 1,
    this.selectedBook,
    this.isSaving     = false,
  });

  BookSearchState copyWith({
    List<BookItem>? results,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    String? query,
    int? currentPage,
    BookItem? selectedBook,
    bool clearSelectedBook = false,
    bool? isSaving,
  }) => BookSearchState(
    results:       results       ?? this.results,
    isLoading:     isLoading     ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error:         error,
    hasMore:       hasMore       ?? this.hasMore,
    query:         query         ?? this.query,
    currentPage:   currentPage   ?? this.currentPage,
    selectedBook:  clearSelectedBook ? null : (selectedBook ?? this.selectedBook),
    isSaving:      isSaving      ?? this.isSaving,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class BookSearchNotifier extends Notifier<BookSearchState> {
  @override
  BookSearchState build() => const BookSearchState();

  AladinDataSource get _aladin => ref.read(aladinDataSourceProvider);
  MyBookDataSource get _myBook => ref.read(myBookDataSourceProvider);

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(isLoading: true, query: query, currentPage: 1);
    try {
      final results = await _aladin.searchByTitle(query, page: 1);
      state = state.copyWith(
        results:    results,
        isLoading:  false,
        hasMore:    results.length >= 50,
        currentPage: 1,
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
      final more = await _aladin.searchByTitle(state.query, page: nextPage);
      state = state.copyWith(
        results:       [...state.results, ...more],
        isLoadingMore: false,
        hasMore:       more.length >= 50,
        currentPage:   nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void selectBook(BookItem book) {
    state = state.copyWith(selectedBook: book);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedBook: true);
  }

  Future<bool> saveBook({
    required BookItem book,
    String? reason,
    String? startedDate,
    String? finishedDate,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      await _myBook.saveMyBook({
        'bookInfo': {
          'source':       'ALADIN',
          'aladinId':     book.itemId,
          'isbn':         book.isbn,
          'title':        book.title,
          'author':       book.author,
          'publisher':    book.publisher,
          'description':  book.description,
          'totalPage':    book.totalPage,
          'publishDate':  book.pubDate,
          'coverImage':   book.cover,
        },
        if (startedDate != null || finishedDate != null)
          'historyInfo': {
            'startedDate':   startedDate,
            'finishedDate':  finishedDate,
          },
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      state = state.copyWith(isSaving: false, clearSelectedBook: true);
      // 홈 화면 갱신
      ref.read(homeProvider.notifier).load();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> saveManualBook({
    required String title,
    required String author,
    String? reason,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      await _myBook.saveMyBook({
        'bookInfo': {
          'source': 'MANUAL',
          'title':  title,
          'author': author,
        },
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      state = state.copyWith(isSaving: false);
      ref.read(homeProvider.notifier).load();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

final bookSearchProvider =
    NotifierProvider<BookSearchNotifier, BookSearchState>(BookSearchNotifier.new);
