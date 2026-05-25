import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../provider/book_search_provider.dart';

class AddBookScreen extends ConsumerWidget {
  const AddBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookSearchProvider).selectedBook;
    if (book == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return const SizedBox.shrink();
    }

    final isSaving = ref.watch(bookSearchProvider).isSaving;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TitleBar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text('책 추가하기',
                      style: AppTypography.dungGeunMoHeader
                          .copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  PixelShadowButton(
                    onTap: isSaving
                        ? () {}
                        : () async {
                            final ok = await ref
                                .read(bookSearchProvider.notifier)
                                .saveBook(book: book);
                            if (ok && context.mounted) context.go('/main/home');
                          },
                    backgroundColor: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('SAVE',
                              style: AppTypography.dungGeunMoBody
                                  .copyWith(color: AppColors.textWhite)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Cover + title
              Center(
                child: Column(
                  children: [
                    if (book.cover.isNotEmpty)
                      CachedNetworkImage(
                          imageUrl: book.cover, width: 120, height: 170,
                          fit: BoxFit.cover)
                    else
                      Container(
                          width: 120, height: 170,
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
                    Text(book.publisher,
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textGray)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Meta
              if (book.totalPage != null)
                _MetaRow('페이지 수', '${book.totalPage}p'),
              if (book.pubDate.isNotEmpty)
                _MetaRow('출간일', book.pubDate),
              if (book.isbn.isNotEmpty)
                _MetaRow('ISBN', book.isbn),
              if (book.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('책 소개',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(book.description,
                    style: AppTypography.wantedSansBodySmall
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppTypography.dungGeunMoSubtitle
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
