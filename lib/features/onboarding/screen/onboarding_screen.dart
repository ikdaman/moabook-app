// lib/features/onboarding/screen/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../features/book_search/provider/book_search_provider.dart';
import '../provider/pending_book_provider.dart';
import '../widget/onboarding_save_popup.dart';
import '../widget/pixel_fireworks.dart';
import '../widget/typing_text.dart';

enum _Step { intro1, intro2, search, done }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro1;
  final _queryCtrl = TextEditingController();

  static const _promptStyleTitle = TextStyle(
      fontFamily: 'DungGeunMo',
      color: AppColors.textWhite,
      fontSize: 28,
      height: 1.7);
  static const _promptStyleBody = TextStyle(
      fontFamily: 'DungGeunMo',
      color: AppColors.textWhite,
      fontSize: 18,
      height: 1.5);

  static const _searchPrompt =
      '요즘 읽고 싶다고 생각한\n책이 있으신가요?\n\n어떤 책인지 궁금해요.';
  static const _donePrompt =
      'BOOK SAVED !\n당신의 읽고 싶은 마음이\n기록됐어요.\n\n로그인하고 이곳에서\n읽고 싶은 책을 모아보세요.';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _goLogin() {
    ref.read(pendingBookProvider.notifier).state = null;
    context.go(Routes.login);
  }

  void _runSearch() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    ref.read(bookSearchProvider.notifier).search(q);
  }

  Future<void> _onBookTap(BookItem book) async {
    final notifier = ref.read(bookSearchProvider.notifier);
    BookItem selected = book;
    if (book.isbn.isNotEmpty) {
      final ok = await notifier.searchByIsbn(book.isbn);
      if (ok) {
        selected = ref.read(bookSearchProvider).selectedBook ?? book;
      } else {
        notifier.selectBook(book);
      }
    } else {
      notifier.selectBook(book);
    }
    if (!mounted) return;
    final result = await showOnboardingSavePopup(context, selected);
    if (!mounted) return;
    if (result != null && result.saved) {
      ref.read(pendingBookProvider.notifier).state =
          PendingBook(book: selected, reason: result.reason);
      setState(() => _step = _Step.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildStep()),
            // Skip (우측 상단, 작은 흰색)
            Positioned(
              top: 8,
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _goLogin,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('건너뛰기',
                      style: AppTypography.dungGeunMoBody.copyWith(
                          color: AppColors.textWhite, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.intro1:
        return Center(
          child: TypingText(
            phrases: const ['모아북'],
            style: _promptStyleTitle,
            eraseAtEnd: true,
            onComplete: () => setState(() => _step = _Step.intro2),
          ),
        );
      case _Step.intro2:
        return Center(
          child: TypingText(
            phrases: const ['읽고 싶은 책을 모아두는\n나만의 공간 !'],
            style: _promptStyleBody,
            eraseAtEnd: true,
            onComplete: () => setState(() => _step = _Step.search),
          ),
        );
      case _Step.search:
        return _SearchStep(
          promptStyle: _promptStyleBody,
          prompt: _searchPrompt,
          queryCtrl: _queryCtrl,
          onSubmit: _runSearch,
          onBookTap: _onBookTap,
        );
      case _Step.done:
        return _DoneStep(
          promptStyle: _promptStyleBody,
          prompt: _donePrompt,
          onStart: _goLogin,
        );
    }
  }
}

class _SearchStep extends ConsumerWidget {
  const _SearchStep({
    required this.promptStyle,
    required this.prompt,
    required this.queryCtrl,
    required this.onSubmit,
    required this.onBookTap,
  });
  final TextStyle promptStyle;
  final String prompt;
  final TextEditingController queryCtrl;
  final VoidCallback onSubmit;
  final Future<void> Function(BookItem) onBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookSearchProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          // 프롬프트는 1회 타이핑 후 유지(검색 step 동안 재타이핑 방지 위해
          // key 고정).
          TypingText(
            key: const ValueKey('search-prompt'),
            phrases: [prompt],
            style: promptStyle,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            color: AppColors.backgroundWhite,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: queryCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSubmit(),
                    style: AppTypography.dungGeunMoBody
                        .copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '책 제목을 검색해주세요.',
                      hintStyle: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textHint),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSubmit,
                  child: const Icon(Icons.search, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: state.results.length,
                    itemBuilder: (_, i) {
                      final b = state.results[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onBookTap(b),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title,
                                  style: AppTypography.wantedSansBookTitle
                                      .copyWith(color: AppColors.textWhite),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${b.author}  ${b.publisher}',
                                  style: AppTypography.wantedSansBodySmall
                                      .copyWith(color: AppColors.textWhite),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.promptStyle,
    required this.prompt,
    required this.onStart,
  });
  final TextStyle promptStyle;
  final String prompt;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 60),
          const SizedBox(width: 268, height: 150, child: PixelFireworks()),
          const SizedBox(height: 24),
          TypingText(
            phrases: [prompt],
            style: promptStyle,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: Container(
                width: double.infinity,
                height: 48,
                color: AppColors.backgroundGray,
                alignment: Alignment.center,
                child: Text('시작하기',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
