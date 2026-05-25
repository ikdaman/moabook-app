import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../provider/book_info_provider.dart';

class BookInfoScreen extends ConsumerWidget {
  final int mybookId;

  const BookInfoScreen({super.key, required this.mybookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookInfoProvider(mybookId));

    if (state.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (state.detail == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error ?? '책 정보를 불러올 수 없습니다.',
                  style: AppTypography.wantedSansBodySmall),
              TextButton(
                  onPressed: () => context.pop(), child: const Text('뒤로가기')),
            ],
          ),
        ),
      );
    }

    final detail = state.detail!;
    final book   = detail.bookInfo;
    final history = detail.historyInfo;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            // TitleBar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, ref),
                    child: Text('삭제',
                        style: AppTypography.dungGeunMoSubtitle
                            .copyWith(color: AppColors.dangerAccent)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover + title
                    Center(
                      child: Column(
                        children: [
                          if (book.coverImage != null)
                            CachedNetworkImage(
                                imageUrl: book.coverImage!,
                                width:    120,
                                height:   170,
                                fit:      BoxFit.cover)
                          else
                            Container(
                                width: 120,
                                height: 170,
                                color: AppColors.surfaceGray),
                          const SizedBox(height: 16),
                          Text(book.title,
                              style: AppTypography.wantedSansBookTitleLarge
                                  .copyWith(color: AppColors.textPrimary),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(book.author,
                              style: AppTypography.wantedSansBodySmall
                                  .copyWith(color: AppColors.textGray)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reading status chip
                    _StatusChip(status: detail.readingStatus),
                    const SizedBox(height: 16),

                    // History dates
                    if (history.startedDate != null)
                      _InfoRow('독서 시작', history.startedDate!),
                    if (history.finishedDate != null)
                      _InfoRow('완독', history.finishedDate!),

                    // Meta
                    if (book.publisher != null)
                      _InfoRow('출판사', book.publisher!),
                    if (book.totalPage != null)
                      _InfoRow('페이지', '${book.totalPage}p'),
                    if (book.isbn != null) _InfoRow('ISBN', book.isbn!),

                    const SizedBox(height: 16),

                    // Reason
                    Text('이 책을 읽고 싶은 이유',
                        style: AppTypography.dungGeunMoSubtitle
                            .copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    PixelShadowBox(
                      backgroundColor: AppColors.backgroundWhite,
                      shadowOffset: 2,
                      contentAlignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          detail.reason?.isNotEmpty == true
                              ? detail.reason!
                              : '이유를 입력해주세요...',
                          style: AppTypography.wantedSansBody.copyWith(
                            color: detail.reason?.isNotEmpty == true
                                ? AppColors.textPrimary
                                : AppColors.textGray,
                          ),
                        ),
                      ),
                    ),

                    // Description
                    if (book.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      Text('책 소개',
                          style: AppTypography.dungGeunMoSubtitle
                              .copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(book.description!,
                          style: AppTypography.wantedSansBodySmall
                              .copyWith(color: AppColors.textPrimary)),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('책 삭제',
            style: AppTypography.dungGeunMoPopupTitle
                .copyWith(color: AppColors.textPrimary)),
        content: Text('책을 삭제하면 모든 기록이 사라져요.\n정말로 삭제하시겠어요?',
            style: AppTypography.wantedSansBody
                .copyWith(color: AppColors.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('삭제',
                  style:
                      TextStyle(color: AppColors.dangerAccent))),
        ],
      ),
    );
    if (ok == true) {
      final deleted =
          await ref.read(bookInfoProvider(mybookId).notifier).delete(mybookId);
      if (deleted && context.mounted) context.pop();
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'WISH'    => ('읽고 싶은 책', AppColors.statusWish),
      'READING' => ('읽는 중',     AppColors.statusReading),
      'DONE'    => ('완독',        AppColors.statusDone),
      _         => (status,        AppColors.surfaceGray),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: color,
      child: Text(label,
          style: AppTypography.dungGeunMoTag
              .copyWith(color: AppColors.textPrimary)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: AppTypography.dungGeunMoTag
                    .copyWith(color: AppColors.textGray)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.wantedSansBodySmall
                    .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
