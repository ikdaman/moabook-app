import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../provider/book_search_provider.dart';

class ManualBookInputScreen extends ConsumerStatefulWidget {
  const ManualBookInputScreen({super.key});

  @override
  ConsumerState<ManualBookInputScreen> createState() =>
      _ManualBookInputScreenState();
}

class _ManualBookInputScreenState
    extends ConsumerState<ManualBookInputScreen> {
  final _titleCtrl  = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(bookSearchProvider).isSaving;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text('직접 입력',
                      style: AppTypography.dungGeunMoHeader
                          .copyWith(color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 32),

              _InputField(
                  label: '책 제목 *', controller: _titleCtrl),
              const SizedBox(height: 16),
              _InputField(
                  label: '저자 *', controller: _authorCtrl),
              const SizedBox(height: 16),
              _InputField(
                  label: '읽고 싶은 이유',
                  controller: _reasonCtrl,
                  maxLines: 3),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: PixelShadowButton(
                  onTap: isSaving
                      ? () {}
                      : () async {
                          final title  = _titleCtrl.text.trim();
                          final author = _authorCtrl.text.trim();
                          if (title.isEmpty || author.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('제목과 저자를 입력해주세요.')),
                            );
                            return;
                          }
                          final ok = await ref
                              .read(bookSearchProvider.notifier)
                              .saveManualBook(
                                title:  title,
                                author: author,
                                reason: _reasonCtrl.text.trim().isEmpty
                                    ? null
                                    : _reasonCtrl.text.trim(),
                              );
                          if (ok && context.mounted) context.go('/main/home');
                        },
                  backgroundColor: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('저장',
                              style: AppTypography.dungGeunMoBody
                                  .copyWith(color: AppColors.textWhite)),
                    ),
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

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines:   maxLines,
          style:      AppTypography.wantedSansBody
              .copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled:      true,
            fillColor:   AppColors.inputBackground,
            border:      const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide:   BorderSide(color: AppColors.borderBlack),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide:
                  BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }
}
