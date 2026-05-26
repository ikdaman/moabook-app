import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/util/date_formatter.dart';
import '../../../shared/widgets/pixel_popup.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../../../shared/widgets/title_bar.dart';
import '../provider/book_info_provider.dart';

class BookInfoScreen extends ConsumerWidget {
  final int mybookId;

  const BookInfoScreen({super.key, required this.mybookId});

  static String _statusDisplay(String value) {
    switch (value.toUpperCase()) {
      case 'INPROGRESS':
        return '읽는 중';
      case 'DONE':
      case 'COMPLETED':
        return '완독';
      case 'TODO':
      default:
        return '읽고 싶은 책';
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: SingleChildScrollView(
          child: PixelPopup(
            onDismiss: () => Navigator.of(ctx).pop(false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('책 삭제',
                    style: AppTypography.dungGeunMoPopupTitle
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                Text('책을 삭제하면 모든 기록이 사라져요.\n정말로 삭제하시겠어요?',
                    style: AppTypography.wantedSansBody
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                PixelPopupActions(
                  cancelLabel: '취소',
                  confirmLabel: '삭제',
                  confirmColor: AppColors.dangerAccent,
                  confirmTextColor: AppColors.textWhite,
                  onCancel: () => Navigator.of(ctx).pop(false),
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (deleted != true) return;
    final ok = await ref.read(bookInfoProvider(mybookId).notifier).delete(mybookId);
    if (ok && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookInfoProvider(mybookId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: state.isLoading
            ? const RetroLoading()
            : _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BookInfoState state) {
    if (state.detail == null) {
      return Column(
        children: [
          TitleBar(
            showBackButton: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error ?? '책 정보를 불러올 수 없습니다.',
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.primary)),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => context.pop(), child: const Text('뒤로가기')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final detail = state.detail!;
    final book = detail.bookInfo;
    final history = detail.historyInfo;

    return Column(
      children: [
        TitleBar(
          showBackButton: true,
          onBack: () => context.pop(),
          rightText: '삭제',
          onRight: () => _confirmDelete(context, ref),
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
                    height: 272,
                    child: book.coverImage != null && book.coverImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: book.coverImage!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                                color: Colors.grey.withValues(alpha: 0.5)),
                            errorWidget: (_, _, _) => Container(
                                color: Colors.grey.withValues(alpha: 0.5)),
                          )
                        : Container(color: Colors.grey.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Text(
                    _statusDisplay(detail.readingStatus),
                    style: AppTypography.dungGeunMoTag
                        .copyWith(color: AppColors.textWhite),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  style: AppTypography.wantedSansBookTitleLarge
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(book.author,
                    style: AppTypography.wantedSansBody
                        .copyWith(color: AppColors.textPrimary)),
                if (book.publisher != null) ...[
                  const SizedBox(height: 8),
                  Text(book.publisher!,
                      style: AppTypography.wantedSansBody
                          .copyWith(color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 30),
                _SectionWithHeader(
                  title: '독서 이력',
                  onEdit: () => _showEditTodo(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                            label: 'SAVE',
                            value: DateFormatter.toShortDate(detail.createdDate)),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'START',
                          value: DateFormatter.toShortDate(history.startedDate)
                                  .isEmpty
                              ? '-'
                              : DateFormatter.toShortDate(history.startedDate),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'FINISH',
                          value: history.finishedDate != null
                              ? DateFormatter.toShortDate(history.finishedDate)
                              : (history.startedDate != null ? '읽는 중' : '-'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionWithHeader(
                  title: '읽고 싶었던 이유',
                  onEdit: () => _showEditTodo(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Text(
                      detail.reason ?? '-',
                      style: AppTypography.wantedSansBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _ShadowInfoField(
                  label: '페이지 수',
                  value: book.totalPage != null ? '${book.totalPage}' : '-',
                ),
                const SizedBox(height: 20),
                _ShadowInfoField(
                  label: '출간일',
                  value: DateFormatter.toShortDate(book.publishDate).isEmpty
                      ? '-'
                      : DateFormatter.toShortDate(book.publishDate),
                ),
                const SizedBox(height: 20),
                _ShadowInfoField(label: 'ISBN', value: book.isbn ?? '-'),
                const SizedBox(height: 20),
                _ShadowInfoField(
                    label: '책 소개', value: book.description ?? '-'),
                const SizedBox(height: 20),
                if (book.aladinId != null)
                  _ShadowBox(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => launchUrl(
                        Uri.parse(
                            'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${book.aladinId}&partner=openAPI&start=api'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditTodo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('편집 기능은 곧 추가될 예정이에요')),
    );
  }
}

/// 흰색 박스 + 우/하 3dp 검정 그림자 (책 정보 더보기, ShadowInfoField 공용)
class _ShadowBox extends StatelessWidget {
  final Widget child;
  const _ShadowBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 3),
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(3, 3),
              child: const DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.borderBlack)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              border: Border.all(color: AppColors.borderBlack),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SectionWithHeader extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final Widget child;

  const _SectionWithHeader({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ShadowBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            color: AppColors.backgroundGray,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(title,
                          style: AppTypography.dungGeunMoSubtitle
                              .copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
                ),
                Container(
                    width: 1, height: 22, color: AppColors.borderBlack),
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 22,
                    child: Center(
                      child: Text('수정',
                          style: AppTypography.dungGeunMoSubtitle
                              .copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderBlack),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: AppTypography.dungGeunMoBody.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 3.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(value,
            style: AppTypography.wantedSansBody
                .copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ShadowInfoField extends StatelessWidget {
  final String label;
  final String value;

  const _ShadowInfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        _ShadowBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(value,
                  style: AppTypography.wantedSansBody
                      .copyWith(color: AppColors.textPrimary)),
            ),
          ),
        ),
      ],
    );
  }
}
