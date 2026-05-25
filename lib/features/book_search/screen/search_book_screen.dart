import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
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
      if (mounted) _focusNode.requestFocus();
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
        context.push(Routes.addBook);
        return;
      }
    }
    // fallback: 검색 결과의 book 을 그대로 선택
    notifier.selectBook(book);
    if (mounted) context.push(Routes.addBook);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _SearchBar(
                controller: _queryCtrl,
                focusNode:  _focusNode,
                onSubmit:   _runSearch,
                onBarcode:  () => context.push(Routes.barcode),
              ),
              const SizedBox(height: 16),
              Expanded(child: _Content(state: state, onBookTap: _onBookTap, scrollController: _scrollCtrl)),
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
    required this.onBarcode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onBarcode;

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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTypography.dungGeunMoBody
                      .copyWith(color: AppColors.textPrimary),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: '책 제목을 검색해주세요.',
                    hintStyle: AppTypography.dungGeunMoBody
                        .copyWith(color: AppColors.textHint),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onBarcode,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: SvgIcon(
                  'assets/images/ic_camera_pixel.svg',
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSubmit,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: SvgIcon(
                  'assets/images/search.svg',
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
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
    required this.scrollController,
  });

  final BookSearchState state;
  final Future<void> Function(BookItem book) onBookTap;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const RetroLoading();
    }
    if (state.results.isEmpty && state.query.isNotEmpty) {
      return _EmptyResult(
        onManualInput: () => context.push(Routes.manualBookInput),
      );
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
                style: AppTypography.dungGeunMoBody
                    .copyWith(color: AppColors.textPrimary),
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
  const _EmptyResult({required this.onManualInput});
  final VoidCallback onManualInput;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '검색 결과가 없습니다.',
            style: AppTypography.dungGeunMoBody.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          PixelShadowButton(
            onTap: onManualInput,
            backgroundColor: AppColors.backgroundGray,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '직접 입력하기',
                style: AppTypography.dungGeunMoSubtitle
                    .copyWith(color: AppColors.textPrimary),
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
                            placeholder: (_, _) => const ColoredBox(
                              color: Colors.grey,
                            ),
                            errorWidget: (_, _, _) => const ColoredBox(
                              color: Colors.red,
                            ),
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
                        style: AppTypography.wantedSansBookTitle
                            .copyWith(color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.publisher,
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textPrimary),
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
