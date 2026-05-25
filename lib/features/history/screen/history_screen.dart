import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/util/date_formatter.dart';
import '../../../domain/model/my_book_detail.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../provider/history_provider.dart';

const _headerGray = Color(0xFFD4D4D4);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider).valueOrNull ?? false;
    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDefault,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '로그인 후 사용이 가능합니다',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(Routes.login),
                  child: Text(
                    '로그인하기',
                    style: AppTypography.dungGeunMoSubtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Stack(
          children: [
            _HistoryBody(state: state),
            if (state.isLoading)
              const Positioned.fill(
                child: RetroLoading(),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.state});
  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.error != null && state.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error!,
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(historyProvider.notifier).load(),
              child: Text(
                '다시 시도',
                style: AppTypography.dungGeunMoSubtitle,
              ),
            ),
          ],
        ),
      );
    }

    final isList = state.viewType == HistoryViewType.list;
    return Column(
      children: [
        _TitleBar(),
        _Toolbar(isList: isList, state: state),
        Expanded(
          child: isList
              ? _ListView(state: state)
              : _GridView(state: state),
        ),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '히스토리',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.isList, required this.state});
  final bool isList;
  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            _ViewToggleButton(
              asset: 'assets/images/ic_list_icon.svg',
              isSelected: isList,
              onTap: () {
                if (!isList) {
                  ref.read(historyProvider.notifier).toggleViewType();
                }
              },
            ),
            const SizedBox(width: 4),
            _ViewToggleButton(
              asset: 'assets/images/ic_grid_icon.svg',
              isSelected: !isList,
              onTap: () {
                if (isList) {
                  ref.read(historyProvider.notifier).toggleViewType();
                }
              },
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(historyProvider.notifier).toggleSort(),
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
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });
  final String asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: PixelShadowButton(
        onTap: onTap,
        isSelected: isSelected,
        backgroundColor: AppColors.backgroundGray,
        child: Center(
          child: SvgIcon(
            asset,
            size: 20,
            color: AppColors.borderBlack,
          ),
        ),
      ),
    );
  }
}

// ── LIST VIEW ─────────────────────────────────────────────────────────────

class _ListView extends ConsumerStatefulWidget {
  const _ListView({required this.state});
  final HistoryState state;

  @override
  ConsumerState<_ListView> createState() => _ListViewState();
}

class _ListViewState extends ConsumerState<_ListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(historyProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.state.books;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
      child: Column(
        children: [
          // Table header
          PixelShadowBox(
            backgroundColor: _headerGray,
            contentAlignment: Alignment.centerLeft,
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'START',
                        style: AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'FINISH',
                        style: AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        '책 이름',
                        style: AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? _EmptyListRow()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: books.length,
                    itemBuilder: (_, i) => _ListItem(
                      book:  books[i],
                      isOdd: i % 2 == 0,
                      onTap: () =>
                          context.push(Routes.bookInfo(books[i].mybookId)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyListRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const Spacer(flex: 2),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                '아직 읽기 시작한 책이 없어요.',
                style: AppTypography.wantedSansBodySmall
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.book,
    required this.isOdd,
    required this.onTap,
  });
  final HistoryBookInfo book;
  final bool isOdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start  = DateFormatter.toShortDate(book.startedDate);
    final finishFormatted = DateFormatter.toShortDate(book.finishedDate);
    final finish = finishFormatted.isEmpty ? '-' : finishFormatted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        color: isOdd ? AppColors.backgroundDefault : Colors.white,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  start,
                  style: AppTypography.wantedSansBodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  finish,
                  style: AppTypography.wantedSansBodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 8),
                child: Text(
                  book.title,
                  style: AppTypography.wantedSansBodySmall
                      .copyWith(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GRID VIEW ─────────────────────────────────────────────────────────────

class _GridView extends ConsumerStatefulWidget {
  const _GridView({required this.state});
  final HistoryState state;

  @override
  ConsumerState<_GridView> createState() => _GridViewState();
}

class _GridViewState extends ConsumerState<_GridView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(historyProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.state.books;
    final bookCount = books.length;
    final emptyCount = bookCount == 0
        ? 3
        : bookCount < 3
            ? 3 - bookCount
            : (3 - bookCount % 3) % 3;
    final totalCells = bookCount + emptyCount;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        mainAxisExtent: 140,
      ),
      itemCount: totalCells,
      itemBuilder: (_, i) {
        if (i >= bookCount) {
          // 빈 칸
          return Container(
            margin: const EdgeInsets.only(right: 1, bottom: 1),
            color: AppColors.backgroundDefault,
          );
        }
        final book = books[i];
        return _GridItem(
          book:  book,
          onTap: () => context.push(Routes.bookInfo(book.mybookId)),
        );
      },
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.book, required this.onTap});
  final HistoryBookInfo book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCover = book.coverImage != null && book.coverImage!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 1, bottom: 1),
      child: PixelShadowButton(
        onTap: onTap,
        backgroundColor: _headerGray,
        child: Center(
          child: hasCover
              ? SizedBox(
                  width: 75,
                  height: 105,
                  child: CachedNetworkImage(
                    imageUrl: book.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Image.asset('assets/images/book_default.png'),
                    errorWidget: (_, _, _) =>
                        Image.asset('assets/images/book_default.png'),
                  ),
                )
              : SizedBox(
                  width: 75,
                  height: 105,
                  child: ColoredBox(
                    color: AppColors.backgroundDefault,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 72,
                          child: Image.asset(
                            'assets/images/book_default.png',
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              book.title,
                              style: AppTypography.wantedSansBodySmall
                                  .copyWith(color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

