import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/book_register_bottom_sheet.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/title_bar.dart';
import '../provider/book_search_provider.dart';

class AddBookScreen extends ConsumerWidget {
  const AddBookScreen({super.key});

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _onSave(BuildContext context, WidgetRef ref) async {
    final book = ref.read(bookSearchProvider).selectedBook;
    if (book == null) return;
    final result = await showBookRegisterSheet(context);
    if (result == null) return;
    final ok = await ref.read(bookSearchProvider.notifier).saveBook(
          book: book,
          reason: result.reason,
          startedDate:
              result.startDate != null ? _isoDate(result.startDate!) : null,
          finishedDate:
              result.endDate != null ? _isoDate(result.endDate!) : null,
        );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('책을 저장했어요')),
      );
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookSearchProvider).selectedBook;
    if (book == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(
              title: '책 추가하기',
              showBackButton: true,
              onBack: () => context.pop(),
              rightText: 'SAVE',
              onRight: () => _onSave(context, ref),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 210,
                        height: 158,
                        child: book.cover.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: book.cover,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                    color: Colors.grey.withValues(alpha: 0.5)),
                                errorWidget: (_, _, _) => Container(
                                    color: Colors.grey.withValues(alpha: 0.5)),
                              )
                            : Container(
                                color: Colors.grey.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      book.title,
                      style: AppTypography.wantedSansBookTitleLarge
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.author,
                      style: AppTypography.wantedSansBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.publisher,
                      style: AppTypography.wantedSansBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    _InfoField(
                        label: '페이지 수',
                        value: '${book.totalPage ?? ''}p'),
                    const SizedBox(height: 20),
                    _InfoField(label: '출간일', value: book.pubDate),
                    const SizedBox(height: 20),
                    _InfoField(label: 'ISBN', value: book.isbn),
                    const SizedBox(height: 20),
                    _InfoField(label: '책 소개', value: book.description),
                    const SizedBox(height: 20),
                    if (book.itemId != 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: PixelShadowButton(
                          onTap: () {
                            final url = Uri.parse(
                                'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${book.itemId}&partner=openAPI&start=api');
                            launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          },
                          backgroundColor: AppColors.backgroundWhite,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '책 정보 더보기',
                                style: AppTypography.wantedSansBody
                                    .copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.dungGeunMoSubtitle
              .copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        PixelShadowBox(
          backgroundColor: AppColors.backgroundWhite,
          contentAlignment: Alignment.centerLeft,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                value,
                style: AppTypography.wantedSansBody
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
