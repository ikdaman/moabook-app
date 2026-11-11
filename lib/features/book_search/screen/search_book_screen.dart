import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../provider/book_search_provider.dart';

class SearchBookScreen extends ConsumerStatefulWidget {
  const SearchBookScreen({super.key});

  @override
  ConsumerState<SearchBookScreen> createState() => _SearchBookScreenState();
}

class _SearchBookScreenState extends ConsumerState<SearchBookScreen> {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    // Android 원본의 LaunchedEffect(Unit) { requestFocus + showKeyboard } 동등
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 화면 재진입 시 이전 검색 결과가 남지 않도록 초기화
      ref.read(bookSearchProvider.notifier).reset();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(bookSearchProvider.notifier).loadMore();
    }
  }

  void _runSearch() {
    _focusNode.unfocus();
    ref.read(bookSearchProvider.notifier).search(_queryCtrl.text);
  }

  Future<void> _onBookTap(BookItem book) async {
    final notifier = ref.read(bookSearchProvider.notifier);
    if (book.isbn.isNotEmpty) {
      // Android 원본: searchBookByIsbn(book.isbn) → ItemLookUp 으로 상세 조회
      final ok = await notifier.searchByIsbn(book.isbn);
      if (!mounted) return;
      if (ok) {
        await context.push(Routes.addBook);
        _clearSearch();
        return;
      }
    }
    // fallback: 검색 결과의 book 을 그대로 선택
    notifier.selectBook(book);
    if (mounted) {
      await context.push(Routes.addBook);
      _clearSearch();
    }
  }

  /// 다른 화면에 갔다 돌아온 뒤 검색 결과가 리스트에 남지 않도록 초기화.
  void _clearSearch() {
    if (!mounted) return;
    _queryCtrl.clear();
    ref.read(bookSearchProvider.notifier).reset();
  }

  void _onSearchAgain() {
    _clearSearch();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookSearchProvider);

    // 초기 상태(검색 전)에만 촬영/갤러리 진입 버튼 노출 — Figma 책추가 탭
    final showCaptureEntries =
        state.query.isEmpty && state.results.isEmpty && !state.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: KeyboardDismisser(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _SearchBar(
                      controller: _queryCtrl,
                      focusNode: _focusNode,
                      onSubmit: _runSearch,
                    ),
                    const SizedBox(height: 16),
                    if (showCaptureEntries) ...[
                      _CaptureEntryButton(
                        icon: Icons.photo_camera_outlined,
                        label: '바코드 스캔',
                        onTap: () => context.push(Routes.capture),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: _Content(
                        state: state,
                        onBookTap: _onBookTap,
                        onSearchAgain: _onSearchAgain,
                        scrollController: _scrollCtrl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Capture entry button ──────────────────────────────────────────────────

/// 촬영/갤러리 진입 버튼 — Figma 책추가 탭의 전체 폭 버튼.
class _CaptureEntryButton extends StatelessWidget {
  const _CaptureEntryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PixelShadowButton(
        onTap: onTap,
        backgroundColor: AppColors.backgroundWhite,
        shadowOffset: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PixelShadowBox(
      backgroundColor: AppColors.backgroundWhite,
      shadowOffset: 2,
      contentAlignment: Alignment.centerLeft,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: SvgIcon(
                'assets/images/search.svg',
                size: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textPrimary,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: '책 제목을 검색해주세요.',
                  hintStyle: AppTypography.dungGeunMoBody.copyWith(
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.onBookTap,
    required this.onSearchAgain,
    required this.scrollController,
  });

  final BookSearchState state;
  final Future<void> Function(BookItem book) onBookTap;
  final VoidCallback onSearchAgain;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const RetroLoading();
    }
    if (state.results.isEmpty && state.query.isNotEmpty) {
      return _EmptyResult(onSearchAgain: onSearchAgain);
    }
    if (state.results.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: state.results.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == state.results.length) {
          // Android 원본: Box fillMaxWidth padding 16, Text "로딩중..."
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '로딩중...',
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        }
        final book = state.results[i];
        return _BookResultItem(book: book, onTap: () => onBookTap(book));
      },
    );
  }
}

// ── EmptyResult ───────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.onSearchAgain});
  final VoidCallback onSearchAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '아직 찾지 못했어요.\n제목의 일부나 저자 이름으로 다시 검색해보세요',
            textAlign: TextAlign.center,
            style: AppTypography.dungGeunMoBody.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          PixelShadowButton(
            onTap: onSearchAgain,
            backgroundColor: AppColors.backgroundGray,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '다른 검색어로 찾아보기',
                style: AppTypography.dungGeunMoSubtitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BookResultItem ────────────────────────────────────────────────────────

class _BookResultItem extends StatelessWidget {
  const _BookResultItem({required this.book, required this.onTap});
  final BookItem book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Cover box: width 86, AsyncImage 84x100 centered
              SizedBox(
                width: 86,
                child: Center(
                  child: SizedBox(
                    width: 84,
                    height: 100,
                    child: book.cover.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: book.cover,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const ColoredBox(color: Colors.grey),
                            errorWidget: (_, _, _) =>
                                const ColoredBox(color: Colors.red),
                          )
                        : const ColoredBox(color: Colors.grey),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 18, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: AppTypography.wantedSansBookTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: AppTypography.wantedSansBodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.publisher,
                        style: AppTypography.wantedSansBodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
