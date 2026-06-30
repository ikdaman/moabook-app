import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasource/mybook_datasource.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../domain/model/login_state.dart';
import '../../../widget_bridge/widget_navigator.dart';
import '../../../widget_bridge/widget_publisher.dart';

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
  final String? snackbarMessage;
  /// 로그인 직후 첫 fetch 가 끝났는지 여부.
  /// false 인 동안에는 빈 CTA 대신 RetroLoading 을 표시해 깜빡임을 방지한다.
  final bool storeBooksLoaded;

  const HomeState({
    this.books            = const [],
    this.isLoading        = false,
    this.isLoadingMore    = false,
    this.error,
    this.hasMore          = true,
    this.sortDescending   = true,
    this.currentPage      = 0,
    this.snackbarMessage,
    this.storeBooksLoaded = false,
  });

  HomeState copyWith({
    List<StoreBookItem>? books,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    bool? sortDescending,
    int? currentPage,
    String? snackbarMessage,
    bool clearSnackbar = false,
    bool? storeBooksLoaded,
  }) => HomeState(
    books:            books            ?? this.books,
    isLoading:        isLoading        ?? this.isLoading,
    isLoadingMore:    isLoadingMore    ?? this.isLoadingMore,
    error:            error,
    hasMore:          hasMore          ?? this.hasMore,
    sortDescending:   sortDescending   ?? this.sortDescending,
    currentPage:      currentPage      ?? this.currentPage,
    snackbarMessage:  clearSnackbar ? null : (snackbarMessage ?? this.snackbarMessage),
    storeBooksLoaded: storeBooksLoaded ?? this.storeBooksLoaded,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class HomeNotifier extends Notifier<HomeState> {
  static const _pageSize = 5;

  @override
  HomeState build() {
    // 로그인 상태 변화 감지: 로그아웃 → 목록 초기화, 로그인 → 재로드
    ref.listen(loginStateProvider, (prev, next) {
      if (next is LoginInitial) {
        state = const HomeState();
        WidgetPublisher.clear();
      }
    });
    ref.listen(isLoggedInProvider, (prev, next) {
      final prevLoggedIn = prev?.valueOrNull;
      final currLoggedIn = next.valueOrNull;
      if (currLoggedIn == false && prevLoggedIn == true) {
        state = const HomeState();
        WidgetPublisher.clear();
      } else if (currLoggedIn == true && prevLoggedIn == false) {
        load();
      }
    });

    // 위젯 refresh 버튼 → 강제 reload (iOS Link 경로)
    final refreshSub = widgetRefreshStream.stream.listen((_) {
      if (ref.read(isLoggedInProvider).valueOrNull == true) {
        load();
      }
    });
    ref.onDispose(refreshSub.cancel);

    // 앱 시작 시 이미 로그인 상태이면 즉시 로드
    // Future.microtask 사용: build() 완료 후 실행되어 상태 업데이트 안전
    Future.microtask(() {
      if (ref.read(isLoggedInProvider).valueOrNull == true) {
        load();
      } else {
        ref.read(isLoggedInProvider.future).then((loggedIn) {
          if (loggedIn) load();
        });
      }
    });

    return const HomeState(isLoading: true);
  }

  MyBookDataSource get _ds => ref.read(myBookDataSourceProvider);

  Future<void> load() async {
    if (ref.read(isLoggedInProvider).valueOrNull != true) {
      state = const HomeState();
      return;
    }
    state = state.copyWith(isLoading: true, currentPage: 0);
    try {
      final result = await _ds.getStoreBooks(
        page: 0,
        size: _pageSize,
        descending: state.sortDescending,
      );
      state = state.copyWith(
        books:            result.content,
        isLoading:        false,
        hasMore:          !result.last,
        currentPage:      0,
        storeBooksLoaded: true,
      );
      // 홈 데이터 갱신 시마다 위젯 publish (최대 9권)
      WidgetPublisher.publish(result.content);
    } catch (e) {
      state = state.copyWith(
        isLoading:        false,
        error:            e.toString(),
        storeBooksLoaded: true,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final result   = await _ds.getStoreBooks(
        page:       nextPage,
        size:       _pageSize,
        descending: state.sortDescending,
      );
      state = state.copyWith(
        books:         [...state.books, ...result.content],
        isLoadingMore: false,
        hasMore:       !result.last,
        currentPage:   nextPage,
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
    try {
      await _ds.deleteMyBook(mybookId);
      state = state.copyWith(
        books:           state.books.where((b) => b.mybookId != mybookId).toList(),
        snackbarMessage: '책이 삭제되었어요.',
      );
    } catch (e) {
      state = state.copyWith(snackbarMessage: '삭제에 실패했어요.');
    }
  }

  Future<void> startReading(
    int mybookId, {
    DateTime? start,
    DateTime? finish,
  }) async {
    try {
      // 00:00 UTC ISO 포맷으로 전송. start 미지정 시 오늘.
      String instant(DateTime d) {
        final u = DateTime.utc(d.year, d.month, d.day);
        return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}T00:00:00Z';
      }

      final startedDate = instant(start ?? DateTime.now());
      final finishedDate = finish != null ? instant(finish) : null;
      await _ds.updateReadingStatus(
        mybookId,
        startedDate: startedDate,
        finishedDate: finishedDate,
      );
      // Android 원본은 mainViewModel.startReading 이후 위젯 새로고침 + 홈 storeBooks 재조회.
      await load();
      state = state.copyWith(snackbarMessage: '시작한 책은 히스토리에서 볼 수 있어요.');
    } catch (e) {
      state = state.copyWith(snackbarMessage: '독서 시작에 실패했어요.');
    }
  }

  void clearSnackbar() {
    state = state.copyWith(clearSnackbar: true);
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);
