import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/util/date_formatter.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/reading_start_bottom_sheet.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../provider/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(homeProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state      = ref.watch(homeProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider).valueOrNull ?? false;

    ref.listen(homeProvider.select((s) => s.snackbarMessage), (_, message) {
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(homeProvider.notifier).clearSnackbar();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Header (설정 아이콘 + 제목 + [+] 책 추가) ───────────────
            const SliverToBoxAdapter(child: _Header()),

            // ── Not logged in ─────────────────────────────────────────
            if (!isLoggedIn)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        '로그인 후 책을 추가해 보세요',
                        style: AppTypography.dungGeunMoSubtitle
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => context.go(Routes.login),
                        child: Image.asset(
                          'assets/images/default_image.png',
                          fit: BoxFit.fitWidth,
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ── First fetch 전 → RetroLoading (깜빡임 방지) ──────────────
            else if (!state.storeBooksLoaded && state.books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox(
                  height: 320,
                  child: RetroLoading(fillBackground: false),
                ),
              )
            // ── Loading (수동 새로고침/정렬변경 등) ────────────────────
            else if (state.isLoading && state.books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: RetroLoading(fillBackground: false),
              )
            // ── Error ──────────────────────────────────────────────
            else if (state.error != null && state.books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.error!,
                        style: AppTypography.dungGeunMoSubtitle.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            ref.read(homeProvider.notifier).load(),
                        child: Text(
                          '다시 시도',
                          style: AppTypography.dungGeunMoSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ── Empty (로그인 + 첫 fetch 완료 + 책 없음) ────────────
            else if (state.books.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      GestureDetector(
                        onTap: () => context.go(Routes.searchBook),
                        child: Image.asset(
                          'assets/images/default_image.png',
                          fit: BoxFit.fitWidth,
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ── Book list ──────────────────────────────────────────
            else ...[
              // Sort bar (정렬 + 내 책 검색 아이콘)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            ref.read(homeProvider.notifier).toggleSort(),
                        child: Row(
                          children: [
                            Text(
                              state.sortDescending ? '최신순' : '오래된순',
                              style: AppTypography.dungGeunMoSubtitle
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(
                                state.sortDescending
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_up,
                                size: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => context.push(Routes.searchMyBook),
                        child: const SvgIcon(
                          'assets/images/search.svg',
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: state.books.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 30),
                  itemBuilder: (context, i) {
                    final book = state.books[i];
                    return _BookCard(
                      book:          book,
                      onTap: () => context.push(Routes.bookInfo(book.mybookId)),
                      onStartReading: () =>
                          _confirmStartReading(context, book),
                      onDelete: () => _confirmDelete(context, book.mybookId),
                    );
                  },
                ),
              ),
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        height: 60,
                        child: RetroLoading(fillBackground: false),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int mybookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(mybookId: mybookId),
    );
    if (confirmed == true) {
      await ref.read(homeProvider.notifier).deleteBook(mybookId);
    }
  }

  Future<void> _confirmStartReading(
    BuildContext context,
    StoreBookItem book,
  ) async {
    final confirmed = await showReadingStartSheet(
      context,
      bookTitle: book.title,
    );
    if (confirmed == true) {
      await ref.read(homeProvider.notifier).startReading(book.mybookId);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings icon (우상단)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 30,
              height: 30,
              child: PixelShadowButton(
                onTap: () => context.push(Routes.setting),
                backgroundColor: AppColors.backgroundGray,
                child: const SvgIcon('assets/images/settings.svg', size: 18),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              '지금 떠오르는\n책이 있나요...!\n',
              style: AppTypography.dungGeunMoHomeTitle
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
          // [+] ADD BOOK
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PixelShadowButton(
                  onTap: () => context.go(Routes.searchBook),
                  backgroundColor: AppColors.backgroundGray,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 4),
                    child: Text(
                      '[+] 책 추가',
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── BookCard ──────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final StoreBookItem book;
  final VoidCallback onTap;
  final VoidCallback onStartReading;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.onTap,
    required this.onStartReading,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormatter.toShortDate(book.createdDate);

    return PixelShadowButton(
      onTap: onTap,
      backgroundColor: AppColors.backgroundWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            height: 30,
            color: AppColors.backgroundGray,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  'NO.${book.mybookId.toString().padLeft(3, '0')}  ($dateStr)',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onStartReading,
                  child: Text(
                    '독서 시작',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  ' ㅣ ',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Text(
                    '삭제',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderBlack),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Center(
                    child: _BookCover(coverImage: book.coverImage),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
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
                        const SizedBox(height: 9),
                        if (book.reason?.isNotEmpty == true)
                          Text(
                            book.reason!,
                            style: AppTypography.wantedSansBodySmall
                                .copyWith(color: AppColors.textPrimary),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            '이 책을 읽고 싶은 이유는 무엇인가요?',
                            style: AppTypography.wantedSansBodySmall.copyWith(
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  final String? coverImage;
  const _BookCover({required this.coverImage});

  @override
  Widget build(BuildContext context) {
    const w = 81.0;
    const h = 114.0;
    final border = Border.all(color: AppColors.borderBlack);
    if (coverImage != null && coverImage!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(border: border),
        child: CachedNetworkImage(
          imageUrl: coverImage!,
          width: w,
          height: h,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        border: border,
      ),
    );
  }
}

// ── DeleteDialog ──────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final int mybookId;

  const _DeleteDialog({required this.mybookId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: PixelShadowBox(
        backgroundColor: AppColors.backgroundWhite,
        shadowOffset: 3,
        contentAlignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: Container(
                  height: 28,
                  color: AppColors.backgroundGray,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 29,
                  height: 28,
                  color: AppColors.backgroundGray,
                  alignment: Alignment.center,
                  child: Text('✕',
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('책 삭제',
                      style: AppTypography.dungGeunMoPopupTitle
                          .copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 20),
                  Text(
                    '책을 삭제하면 모든 기록이 사라져요.\n정말로 삭제하시겠어요?',
                    style: AppTypography.wantedSansBody
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PixelShadowButton(
                        onTap: () => Navigator.pop(context, false),
                        backgroundColor: AppColors.backgroundGray,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text('취소',
                              style: AppTypography.dungGeunMoBody
                                  .copyWith(color: AppColors.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 50),
                      PixelShadowButton(
                        onTap: () => Navigator.pop(context, true),
                        backgroundColor: AppColors.dangerAccent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text('삭제',
                              style: AppTypography.dungGeunMoBody
                                  .copyWith(color: AppColors.textWhite)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
