import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../provider/book_search_provider.dart';

class SearchBookScreen extends ConsumerStatefulWidget {
  const SearchBookScreen({super.key});

  @override
  ConsumerState<SearchBookScreen> createState() => _SearchBookScreenState();
}

class _SearchBookScreenState extends ConsumerState<SearchBookScreen> {
  final _queryCtrl     = TextEditingController();
  final _scrollCtrl    = ScrollController();
  final _focusRequester = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    _focusRequester.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(bookSearchProvider.notifier).loadMore();
    }
  }

  void _search() {
    _focusRequester.unfocus();
    ref.read(bookSearchProvider.notifier).search(_queryCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color:  AppColors.backgroundWhite,
                        border: Border.all(color: AppColors.borderBlack),
                      ),
                      child: TextField(
                        controller:  _queryCtrl,
                        focusNode:   _focusRequester,
                        style:       AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText:       '책 제목을 검색해주세요.',
                          hintStyle:      AppTypography.dungGeunMoBody
                              .copyWith(color: AppColors.textHint),
                          border:         InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted:    (_) => _search(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Barcode
                  GestureDetector(
                    onTap: () => context.push(Routes.barcode),
                    child: const Icon(Icons.qr_code_scanner,
                        color: AppColors.textPrimary, size: 28),
                  ),
                  const SizedBox(width: 8),
                  // Search button
                  GestureDetector(
                    onTap: _search,
                    child: const Icon(Icons.search,
                        color: AppColors.textPrimary, size: 28),
                  ),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.results.isEmpty && state.query.isNotEmpty
                      ? _EmptyResult(
                          onManualInput: () =>
                              context.push(Routes.manualBookInput),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding:    const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount:  state.results.length +
                              (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == state.results.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            return _BookResultItem(
                              book:  state.results[i],
                              onTap: () {
                                ref
                                    .read(bookSearchProvider.notifier)
                                    .selectBook(state.results[i]);
                                context.push(Routes.addBook);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EmptyResult ───────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  final VoidCallback onManualInput;

  const _EmptyResult({required this.onManualInput});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('검색 결과가 없습니다.',
              style: AppTypography.dungGeunMoSubtitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          PixelShadowButton(
            onTap: onManualInput,
            backgroundColor: AppColors.backgroundGray,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('직접 입력하기',
                  style: AppTypography.dungGeunMoBody
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BookResultItem ────────────────────────────────────────────────────────

class _BookResultItem extends StatelessWidget {
  final BookItem book;
  final VoidCallback onTap;

  const _BookResultItem({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:   const EdgeInsets.only(bottom: 12),
        color:    AppColors.backgroundWhite,
        padding:  const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            book.cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: book.cover,
                    width:    60,
                    height:   85,
                    fit:      BoxFit.cover,
                  )
                : Container(
                    width: 60, height: 85,
                    color: AppColors.surfaceGray),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: AppTypography.wantedSansBookTitle
                          .copyWith(color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(book.author,
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(book.publisher,
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
