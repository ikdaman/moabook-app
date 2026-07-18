import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasource/aladin_datasource.dart';
import '../../../data/datasource/mybook_datasource.dart';
import '../../../domain/model/book_item.dart';
import '../../../features/home/provider/home_provider.dart';
import '../../home/screen/pending_book_consumer.dart';

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

class BookSearchNotifier extends Notifier<BookSearchState>
    implements PendingSaver {
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

  /// 검색 화면 재진입 시 이전 검색 결과가 남지 않도록 초기 상태로 되돌린다.
  void reset() {
    state = const BookSearchState();
  }

  /// ISBN으로 알라딘 단건 조회. 결과를 [selectedBook]에 세팅.
  /// 성공 시 true, 결과가 없거나 실패 시 false.
  /// 검색 목록([results]/[query])은 건드리지 않는다 — 바코드/표지 플로우가
  /// 아래에 깔린 검색 화면의 목록을 덮어쓰면 안 되기 때문.
  Future<bool> searchByIsbn(String isbn) async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await _aladin.searchByIsbn(isbn);
      if (results.isEmpty) {
        state = state.copyWith(isLoading: false, error: '해당 ISBN의 책을 찾을 수 없어요.');
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        selectedBook: results.first,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// ISBN 상세 조회만 수행하고 [results]/[state] 는 건드리지 않는다.
  /// 온보딩에서 검색 목록을 유지한 채 선택 책의 상세(쪽수 등)를 가져올 때 사용.
  /// [searchByIsbn] 과 달리 결과 목록을 덮어쓰지 않는다.
  Future<BookItem?> lookupDetail(String isbn) async {
    if (isbn.isEmpty) return null;
    try {
      final results = await _aladin.searchByIsbn(isbn);
      return results.isEmpty ? null : results.first;
    } catch (_) {
      return null;
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

  @override
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
          'source': 'CUSTOM',
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
