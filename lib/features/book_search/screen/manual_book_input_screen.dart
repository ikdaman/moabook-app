import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../shared/widgets/book_register_bottom_sheet.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/title_bar.dart';
import '../provider/book_search_provider.dart';

class ManualBookInputScreen extends ConsumerStatefulWidget {
  const ManualBookInputScreen({super.key});

  @override
  ConsumerState<ManualBookInputScreen> createState() =>
      _ManualBookInputScreenState();
}

class _ManualBookInputScreenState extends ConsumerState<ManualBookInputScreen> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _publisher = TextEditingController();
  final _pubDate = TextEditingController();
  final _isbn = TextEditingController();
  final _pageCount = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _pubDate.dispose();
    _isbn.dispose();
    _pageCount.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final title = _title.text.trim();
    final author = _author.text.trim();
    if (title.isEmpty || author.isEmpty) return;
    final result = await showBookRegisterSheet(context);
    if (result == null || !mounted) return;
    final ok = await ref
        .read(bookSearchProvider.notifier)
        .saveManualBook(title: title, author: author, reason: result.reason);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('책을 저장했어요')));
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: KeyboardDismisser(
        child: SafeArea(
          child: Column(
            children: [
              TitleBar(
                title: '직접 입력',
                showBackButton: true,
                onBack: () => context.pop(),
                rightText: 'SAVE',
                onRight: _onSave,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Image.asset(
                        'assets/images/book_default.png',
                        width: 131,
                        height: 181,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: '제목',
                        required: true,
                        controller: _title,
                        hint: '책 제목을 입력하세요',
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: '작가',
                        required: true,
                        controller: _author,
                        hint: '작가를 입력하세요',
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: '출판사',
                        controller: _publisher,
                        hint: '출판사를 입력하세요',
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: '출간일',
                        controller: _pubDate,
                        hint: 'YYYY-MM-DD',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: 'ISBN',
                        controller: _isbn,
                        hint: 'ISBN을 입력하세요',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      _Field(
                        label: '페이지 수',
                        controller: _pageCount,
                        hint: '페이지 수를 입력하세요',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 32),
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

class _Field extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    this.required = false,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              style: AppTypography.dungGeunMoSubtitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '필수',
                style: AppTypography.dungGeunMoTag.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          color: AppColors.backgroundWhite,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTypography.wantedSansBody.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTypography.wantedSansBody.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
