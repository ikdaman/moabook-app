import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
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
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _Header(isLoggedIn: isLoggedIn)),

            // ── Not logged in ─────────────────────────────────────────
            if (!isLoggedIn)
              SliverFillRemaining(
                child: Center(
                  child: GestureDetector(
                    onTap: () => context.go(Routes.login),
                    child: Text(
                      '로그인 후 책을 추가해 보세요',
                      style: AppTypography.dungGeunMoSubtitle
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
              )
            else ...[
              // ── Sort bar ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                            Icon(
                              state.sortDescending
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Loading ────────────────────────────────────────────
              if (state.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )

              // ── Error ──────────────────────────────────────────────
              else if (state.error != null && state.books.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.error!,
                            style: AppTypography.wantedSansBodySmall),
                        TextButton(
                          onPressed: () =>
                              ref.read(homeProvider.notifier).load(),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )

              // ── Empty ──────────────────────────────────────────────
              else if (state.books.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => context.go(Routes.searchBook),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '지금 떠오르는\n책이 있나요...!\n',
                            textAlign: TextAlign.center,
                            style: AppTypography.dungGeunMoHomeTitle
                                .copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          PixelShadowBox(
                            backgroundColor: AppColors.backgroundGray,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
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
                  ),
                )

              // ── Book list ──────────────────────────────────────────
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.separated(
                    itemCount: state.books.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final book = state.books[i];
                      return _BookCard(
                        index:         state.totalIndex(i),
                        book:          book,
                        onTap: () => context.push(Routes.bookInfo(book.mybookId)),
                        onStartReading: () => ref
                            .read(homeProvider.notifier)
                            .startReading(book.mybookId),
                        onDelete: () => _confirmDelete(context, book.mybookId),
                      );
                    },
                  ),
                ),
                if (state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
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
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final bool isLoggedIn;

  const _Header({required this.isLoggedIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: isLoggedIn
                ? GestureDetector(
                    onTap: () => context.push(Routes.searchMyBook),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        border: Border.all(color: AppColors.borderBlack),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '내 책 검색',
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textGray),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push(Routes.setting),
            child: const Icon(Icons.settings, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── BookCard ──────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final int index;
  final StoreBookItem book;
  final VoidCallback onTap;
  final VoidCallback onStartReading;
  final VoidCallback onDelete;

  const _BookCard({
    required this.index,
    required this.book,
    required this.onTap,
    required this.onStartReading,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = book.createdDate.length >= 8
        ? book.createdDate.substring(2, 8)
        : book.createdDate;

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
                  '#${index.toString().padLeft(3, '0')}  ($dateStr)',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onStartReading,
                  child: Text('독서 시작',
                      style: AppTypography.dungGeunMoSubtitle
                          .copyWith(color: AppColors.textPrimary)),
                ),
                Text(' ㅣ ',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: onDelete,
                  child: Text('삭제',
                      style: AppTypography.dungGeunMoSubtitle
                          .copyWith(color: AppColors.textPrimary)),
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
                // Cover
                SizedBox(
                  width: 110,
                  child: Center(
                    child: book.coverImage != null
                        ? CachedNetworkImage(
                            imageUrl: book.coverImage!,
                            width: 81,
                            height: 114,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 81,
                            height: 114,
                            color: AppColors.surfaceGray,
                          ),
                  ),
                ),
                // Info
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
                        Text(
                          book.reason?.isNotEmpty == true
                              ? book.reason!
                              : '이 책을 읽고 싶은 이유는 무엇인가요?',
                          style: AppTypography.wantedSansBodySmall.copyWith(
                            color: book.reason?.isNotEmpty == true
                                ? AppColors.textPrimary
                                : AppColors.textGray,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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

// Extension
extension HomeStateX on HomeState {
  int totalIndex(int listIndex) => totalElements - (currentPage * 10) - listIndex;
  int get totalElements => books.length; // 간단 구현 (정확한 값은 서버 응답에서)
}
