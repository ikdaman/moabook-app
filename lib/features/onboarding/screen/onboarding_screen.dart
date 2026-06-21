// lib/features/onboarding/screen/onboarding_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum _Step { intro, search, done }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.intro;
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

  // Skip: 보류책 버리고 로그인
  void _skipToLogin() {
    ref.read(pendingBookProvider.notifier).state = null;
    context.go(Routes.login);
  }

  // 시작하기: 보류책 유지하고 로그인 (Home에서 소비)
  void _startToLogin() {
    context.go(Routes.login);
  }

  void _runSearch() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    ref.read(bookSearchProvider.notifier).search(q);
  }

  Future<void> _onBookTap(BookItem book) async {
    final notifier = ref.read(bookSearchProvider.notifier);
    // 상세(쪽수 등)만 가져오고 검색 목록은 유지한다. searchByIsbn 은 results 를
    // 덮어써서 팝업을 닫으면 목록이 사라지므로 lookupDetail 을 쓴다.
    BookItem selected = book;
    if (book.isbn.isNotEmpty) {
      final detail = await notifier.lookupDetail(book.isbn);
      if (detail != null) selected = detail;
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
    // 네이비 배경 → 상태바 아이콘/텍스트 밝게(흰색).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: Scaffold(
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
                onTap: _skipToLogin,
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
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.intro:
        return _IntroStep(
          titleStyle: _promptStyleTitle,
          bodyStyle: _promptStyleBody,
          onDone: () => setState(() => _step = _Step.search),
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
          onStart: _startToLogin,
        );
    }
  }
}

// 모든 온보딩 step 에서 아이콘 위치를 고정하기 위한 공통 좌표(Figma 기준).
// 아이콘·프롬프트는 좌측 40 들여쓰기, 상단 120 에 정렬 → 화면 전환 시 아이콘이
// 움직이지 않는다. 검색창/리스트만 16 들여쓰기로 더 넓게 쓴다.
const double _kIconIndent = 40;
const double _kIconTop = 120;
const double _kSearchIndent = 16;

/// 온보딩 공통 앱 아이콘 (50x50, 픽셀 책). intro/검색 화면 상단에 노출.
class _OnboardingIcon extends StatelessWidget {
  const _OnboardingIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/book_icon.png',
      width: 50,
      height: 50,
      filterQuality: FilterQuality.none, // 픽셀 느낌 유지
    );
  }
}

/// intro 화면(Figma frame 2): 앱 아이콘 + "모 아 북"(28) + 부제(18).
/// 한 화면에서 제목을 먼저 타이핑하고, 끝나면 그 밑 부제까지 이어서 타이핑한다
/// (2단계로 화면을 나누지 않음). 부제까지 끝나면 [onDone] 으로 검색 step 진입.
class _IntroStep extends StatefulWidget {
  const _IntroStep({
    required this.titleStyle,
    required this.bodyStyle,
    required this.onDone,
  });
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final VoidCallback onDone;

  @override
  State<_IntroStep> createState() => _IntroStepState();
}

class _IntroStepState extends State<_IntroStep> {
  // 제목 타이핑이 끝나야 부제 타이핑을 시작한다.
  bool _titleDone = false;
  // 부제 역삭제까지 끝나면 제목도 한 글자씩 지운 뒤 다음 step 으로 넘어간다.
  bool _eraseTitle = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kIconIndent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _kIconTop),
          const _OnboardingIcon(),
          const SizedBox(height: 12),
          // 제목 "모 아 북" (28) — 타이핑 후 유지. 부제 삭제가 끝나면(_eraseTitle)
          // startFull 로 떠 있는 상태에서 한 글자씩 지우고 onDone 으로 전환.
          if (!_eraseTitle)
            TypingText(
              key: const ValueKey('intro-title'),
              phrases: const ['모 아 북'],
              style: widget.titleStyle,
              textAlign: TextAlign.left,
              startDelay: const Duration(milliseconds: 600),
              onComplete: () {
                if (mounted) setState(() => _titleDone = true);
              },
            )
          else
            TypingText(
              key: const ValueKey('intro-title-erase'),
              phrases: const ['모 아 북'],
              style: widget.titleStyle,
              textAlign: TextAlign.left,
              startFull: true,
              eraseAtEnd: true,
              holdDuration: Duration.zero,
              onComplete: widget.onDone,
            ),
          // 부제(18) — 제목 완료 후 그 밑에 이어서 타이핑. 다 읽을 시간(hold) 뒤
          // 한 글자씩 역삭제하고 끝나면 제목 삭제를 시작한다.
          if (_titleDone && !_eraseTitle) ...[
            const SizedBox(height: 12),
            TypingText(
              key: const ValueKey('intro-body'),
              phrases: const ['읽고 싶은 책을 모아두는\n나만의 공간 !'],
              style: widget.bodyStyle,
              textAlign: TextAlign.left,
              eraseAtEnd: true,
              onComplete: () {
                if (mounted) setState(() => _eraseTitle = true);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchStep extends ConsumerStatefulWidget {
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
  ConsumerState<_SearchStep> createState() => _SearchStepState();
}

class _SearchStepState extends ConsumerState<_SearchStep> {
  // 프롬프트 타이핑이 끝나기 전엔 검색창/리스트를 숨긴다.
  bool _promptDone = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // 프롬프트 완료 → 검색창 노출 + 키보드 포커스.
  void _onPromptDone() {
    if (_promptDone) return;
    setState(() => _promptDone = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookSearchProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kSearchIndent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _kIconTop),
          // 아이콘·프롬프트는 intro 와 같은 좌측 40 위치에 맞춘다(아이콘 고정).
          // 바깥 Padding 이 16 이므로 추가로 (_kIconIndent - _kSearchIndent) 만큼 민다.
          Padding(
            padding: const EdgeInsets.only(
                left: _kIconIndent - _kSearchIndent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OnboardingIcon(),
                const SizedBox(height: 12),
                // 프롬프트는 1회 타이핑 후 유지(검색 step 동안 재타이핑 방지
                // 위해 key 고정). 완료되면 검색창을 노출한다.
                TypingText(
                  key: const ValueKey('search-prompt'),
                  phrases: [widget.prompt],
                  style: widget.promptStyle,
                  textAlign: TextAlign.left,
                  onComplete: _onPromptDone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // 검색창·결과는 프롬프트 타이핑이 끝난 뒤에만 노출.
          if (_promptDone) ...[
            Container(
              height: 48,
              color: AppColors.backgroundWhite,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.queryCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => widget.onSubmit(),
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
                    onTap: widget.onSubmit,
                    child: const Icon(Icons.search,
                        color: AppColors.textPrimary),
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
                      itemBuilder: (_, i) => _ResultItem(
                          book: state.results[i], onTap: widget.onBookTap),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 온보딩 검색 결과 아이템 (Figma frame 4).
/// 썸네일(84x120, 흰 배경) + 제목/작가/출판사. 텍스트 흰색.
class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.book, required this.onTap});
  final BookItem book;
  final Future<void> Function(BookItem) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(book),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일: 흰 배경 박스 위 커버 이미지.
            SizedBox(
              width: 86,
              height: 120,
              child: ColoredBox(
                color: AppColors.backgroundWhite,
                child: book.cover.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.cover,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const ColoredBox(color: AppColors.backgroundGray),
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: AppColors.backgroundGray),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: AppTypography.wantedSansBookTitle
                          .copyWith(color: AppColors.textWhite),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(book.author,
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textWhite),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(book.publisher,
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textWhite),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneStep extends StatefulWidget {
  const _DoneStep({
    required this.promptStyle,
    required this.prompt,
    required this.onStart,
  });
  final TextStyle promptStyle;
  final String prompt;
  final VoidCallback onStart;

  @override
  State<_DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<_DoneStep> {
  // 텍스트 타이핑이 끝나기 전엔 시작하기 버튼을 숨긴다.
  bool _textDone = false;

  void _onTextDone() {
    if (!_textDone && mounted) setState(() => _textDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // Figma frame 6: 상단 앵커. 폭죽 → gap40 → 텍스트(좌측정렬) → gap40 →
    // 작은 가운데 버튼. 버튼은 전체폭/바닥 고정 아님.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 90),
        const SizedBox(width: 268, height: 150, child: PixelFireworks()),
        const SizedBox(height: 40),
        // 텍스트 블록: 좌우 30 패딩, 좌측정렬.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SizedBox(
            width: double.infinity,
            child: TypingText(
              phrases: [widget.prompt],
              style: widget.promptStyle,
              textAlign: TextAlign.left,
              onComplete: _onTextDone,
            ),
          ),
        ),
        const SizedBox(height: 40),
        // 시작하기: 텍스트 타이핑 완료 후 노출. 작은 pill, 가운데정렬.
        if (_textDone)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onStart,
            child: Container(
              color: AppColors.backgroundGray,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('시작하기',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}
