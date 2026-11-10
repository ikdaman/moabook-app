import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import '../../../app/router/routes.dart';
import '../../../shared/widgets/root_back_guard.dart';
import '../../../domain/model/book_item.dart';
import '../../book_search/provider/book_search_provider.dart';
import '../onboarding_prefs.dart';
import '../provider/pending_book_provider.dart';
import '../widget/onboarding_book.dart';
import '../widget/onboarding_save_popup.dart';
import '../widget/typing_text.dart';

enum _Step { intro, search, done }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const palette = DesignPalette(Mood.a);
  static const paper = Color(0xfff4f1ea);
  static const muted = Color(0xffb9b5ac);
  _Step _step = _Step.intro;
  final _queryCtrl = TextEditingController();
  BookItem? _selectedBook;
  String? _reason;
  bool _choosing = false;
  int? _loadingBookId;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _skipToLogin() {
    ref.read(pendingBookProvider.notifier).state = null;
    markOnboardingSeen();
    context.go(Routes.login);
  }

  void _startToLogin() {
    markOnboardingSeen();
    context.go(Routes.login);
  }

  void _runSearch() {
    final query = _queryCtrl.text.trim();
    if (query.isNotEmpty) ref.read(bookSearchProvider.notifier).search(query);
  }

  Future<void> _onBookTap(BookItem book) async {
    if (_choosing) return;
    setState(() {
      _choosing = true;
      _loadingBookId = book.itemId;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      BookItem selected = book;
      if (book.isbn.isNotEmpty && book.totalPage == null) {
        selected =
            await ref
                .read(bookSearchProvider.notifier)
                .lookupDetail(book.isbn) ??
            book;
      }
      if (!mounted) return;
      setState(() => _loadingBookId = null);
      final result = await showOnboardingSavePopup(
        context,
        selected,
        initialReason: _selectedBook?.itemId == selected.itemId
            ? _reason
            : null,
      );
      if (!mounted || result == null || !result.saved) return;
      ref.read(pendingBookProvider.notifier).state = PendingBook(
        book: selected,
        reason: result.reason,
      );
      setState(() {
        _selectedBook = selected;
        _reason = result.reason;
        _step = _Step.done;
      });
    } finally {
      if (mounted) {
        setState(() {
          _choosing = false;
          _loadingBookId = null;
        });
      }
    }
  }

  void _showSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = _Step.search);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: palette.theme,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: palette.ink,
      ),
      child: RootBackGuard(
        blocked: _choosing,
        onBack: _step == _Step.intro
            ? null
            : () => setState(
                () => _step = _step == _Step.done ? _Step.search : _Step.intro,
              ),
        child: Scaffold(
          backgroundColor: palette.ink,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 10, 0),
                  child: Row(
                    children: [
                      Text(
                        'MOABOOK / ${_step == _Step.intro
                            ? 'PROLOGUE'
                            : _step == _Step.search
                            ? '01'
                            : '02'}',
                        style: palette.text(10, mono: true, color: muted),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _choosing ? null : _skipToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: paper,
                          textStyle: palette.text(12, color: paper),
                        ),
                        child: const Text('건너뛰기'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .025),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: switch (_step) {
                      _Step.intro => _intro(),
                      _Step.search => _search(),
                      _Step.done => _done(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _primary(String title, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: paper,
        foregroundColor: palette.ink,
        minimumSize: const Size.fromHeight(54),
        shape: const RoundedRectangleBorder(),
        textStyle: palette.text(15, weight: 600),
      ),
      child: Text(title),
    ),
  );

  Widget _intro() => LayoutBuilder(
    key: const ValueKey('onboarding-intro'),
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 44).clamp(0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 26, height: 4, color: palette.orange),
              const Spacer(),
              const SizedBox(height: 44),
              _prompt('책과 함께한 시간은\n어디에 남아 있나요?', size: 29, identity: 'intro'),
              const SizedBox(height: 22),
              Text(
                '읽고 싶어진 순간부터\n오래 기억하고 싶은 문장까지.',
                style: palette.text(14, color: muted, height: 1.8),
              ),
              const SizedBox(height: 44),
              const Spacer(),
              Divider(height: 1, color: paper.withValues(alpha: .3)),
              const SizedBox(height: 22),
              Text('한 권으로 시작하는 나만의 서가', style: palette.text(12, color: muted)),
              const SizedBox(height: 14),
              _primary('첫 책 고르기', _showSearch),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _prompt(String text, {required String identity, double size = 26}) {
    final style = palette.text(
      size,
      serif: true,
      weight: 600,
      color: paper,
      height: 1.5,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(text, style: style);
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Opacity(opacity: 0, child: Text(text, style: style)),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topLeft,
                child: TypingText(
                  key: ValueKey(identity),
                  phrases: [text],
                  style: style,
                  textAlign: TextAlign.left,
                  charInterval: const Duration(milliseconds: 45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _search() {
    final state = ref.watch(bookSearchProvider);
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 640;
    return Column(
      key: const ValueKey('onboarding-search'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            compact ? 8 : 18,
            22,
            compact ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Text(
                  '어떤 책을 찾고 있나요?',
                  style: palette.text(
                    20,
                    serif: true,
                    color: paper,
                    weight: 600,
                  ),
                )
              else ...[
                _prompt('요즘 읽고 싶은 책이\n있으신가요?', identity: 'search', size: 25),
                const SizedBox(height: 12),
                Text(
                  '제목이나 작가 이름으로 찾아보세요.',
                  style: palette.text(12, color: muted),
                ),
              ],
              SizedBox(height: compact ? 12 : 20),
              TextField(
                controller: _queryCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                style: palette.text(16),
                decoration: InputDecoration(
                  hintText: '책 제목 또는 작가',
                  hintStyle: palette.text(14, color: palette.muted),
                  filled: true,
                  fillColor: paper,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: palette.orange, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    tooltip: '책 검색',
                    onPressed: _runSearch,
                    icon: DesignIcon('search', color: palette.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? Center(child: CircularProgressIndicator(color: paper))
              : state.error != null
              ? _searchMessage(
                  '책을 찾지 못했어요.',
                  '연결을 확인하고 다시 시도해주세요.',
                  retry: true,
                )
              : state.query.isEmpty
              ? _searchMessage('어떤 책이든 좋아요.', '제목의 일부만 떠올라도 괜찮아요.')
              : state.results.isEmpty
              ? _searchMessage('아직 찾지 못했어요.', '제목의 일부나 저자 이름으로 다시 검색해보세요')
              : NotificationListener<ScrollNotification>(
                  onNotification: (event) {
                    if (event.metrics.axis == Axis.vertical &&
                        event.metrics.extentAfter < 240 &&
                        state.hasMore &&
                        !state.isLoadingMore) {
                      ref.read(bookSearchProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount:
                        state.results.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: paper.withValues(alpha: .2)),
                    itemBuilder: (context, index) =>
                        index == state.results.length
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(color: paper),
                            ),
                          )
                        : _result(state.results[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _searchMessage(String title, String subtitle, {bool retry = false}) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: palette.text(17, serif: true, color: paper, weight: 600),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: palette.text(12, color: muted),
                textAlign: TextAlign.center,
              ),
              if (retry)
                TextButton(
                  onPressed: _runSearch,
                  child: Text('다시 찾기', style: palette.text(13, color: paper)),
                ),
            ],
          ),
        ),
      );

  Widget _result(BookItem book) => InkWell(
    onTap: _choosing ? null : () => _onBookTap(book),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingBook(book: book, width: 64, height: 90),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: palette.text(16, weight: 600, color: paper),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  book.author,
                  style: palette.text(12, color: muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  book.publisher,
                  style: palette.text(11, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _loadingBookId == book.itemId
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: paper,
                  ),
                )
              : const DesignIcon('chevron-right', color: muted, size: 18),
        ],
      ),
    ),
  );

  Widget _done() => LayoutBuilder(
    key: const ValueKey('onboarding-done'),
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 30).clamp(0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FirstBookShelf(book: _selectedBook!),
              const SizedBox(height: 28),
              Text(
                '첫 책을 골랐어요.',
                style: palette.text(27, serif: true, weight: 600, color: paper),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedBook!.title,
                style: palette.text(16, color: paper, weight: 600),
              ),
              if (_reason?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: palette.orange, width: 3),
                    ),
                  ),
                  child: Text(
                    _reason!,
                    style: palette.text(13, color: muted),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                '로그인하면 이 책이 내 서가에 꽂혀요.\n독서카드에서 첫 기록을 남겨보세요.',
                style: palette.text(13, color: muted, height: 1.8),
              ),
              const SizedBox(height: 30),
              const Spacer(),
              _primary('로그인하고 서가 시작하기', _startToLogin),
              Center(
                child: TextButton(
                  onPressed: _showSearch,
                  child: Text(
                    '다른 책 고르기',
                    style: palette.text(12, color: muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
