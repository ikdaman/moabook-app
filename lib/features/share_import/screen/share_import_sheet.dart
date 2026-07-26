// 갤러리 공유 플로우 바텀시트.
//
// 투명 ShareActivity 위에 하단 시트만 노출한다. (Figma
// "2. 갤러리에서 추가(바텀시트)_260723" 3단계 + 오류 케이스)
// 상단 dim 영역 탭 → 닫기.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../provider/share_import_provider.dart';

class ShareImportSheet extends ConsumerStatefulWidget {
  const ShareImportSheet({super.key});

  @override
  ConsumerState<ShareImportSheet> createState() => _ShareImportSheetState();
}

class _ShareImportSheetState extends ConsumerState<ShareImportSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareImportProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shareImportProvider);
    final notifier = ref.read(shareImportProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // dim 영역: 탭하면 닫기.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: notifier.close,
              child: const ColoredBox(color: Colors.black26),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            decoration: const BoxDecoration(
              color: AppColors.backgroundDefault,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: _body(state, notifier),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ShareImportState state, ShareImportNotifier notifier) {
    return switch (state.step) {
      ShareImportStep.loading  => const _LoadingView(),
      ShareImportStep.pickBook => _PickBookView(
          results: state.results,
          isSaving: state.isSaving,
          onTap: notifier.save,
        ),
      ShareImportStep.saved    => _SavedView(
          book: state.savedBook!,
          onOpenApp: notifier.openApp,
        ),
      ShareImportStep.error    => _ErrorView(
          kind: state.error ?? ShareImportError.network,
          onOpenApp: notifier.openApp,
          onClose: notifier.close,
        ),
    };
  }
}

Widget _title(String text) => Text(
      text,
      style: AppTypography.dungGeunMoPopupTitle
          .copyWith(color: AppColors.textPrimary),
    );

// ── Step 1: 검색 중 ────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('일치하는 책을 검색 중이에요...'),
        const SizedBox(height: 72),
        Center(
          child: Image.asset(
            'assets/images/mascot_bounce.gif',
            width: 96,
            height: 96,
          ),
        ),
        const SizedBox(height: 140),
      ],
    );
  }
}

// ── Step 2: 책 선택 ────────────────────────────────────────────────────────

class _PickBookView extends StatelessWidget {
  const _PickBookView({
    required this.results,
    required this.isSaving,
    required this.onTap,
  });

  final List<BookItem> results;
  final bool isSaving;
  final void Function(BookItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('일치하는 책을 선택해주세요.'),
        const SizedBox(height: 12),
        Text(
          '※ 사진에 텍스트가 많은 경우, 내가 찾는 책이 하단에 보일 수 있어요.',
          style: AppTypography.wantedSansBodySmall
              .copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _BookRow(
              book: results[i],
              enabled: !isSaving,
              onTap: () => onTap(results[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.enabled,
    required this.onTap,
  });

  final BookItem book;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cover(book.cover, width: 64, height: 90),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: AppTypography.wantedSansBookTitle
                      .copyWith(color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  book.author,
                  style: AppTypography.wantedSansBodySmall
                      .copyWith(color: AppColors.textGray),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  book.publisher,
                  style: AppTypography.wantedSansBodySmall
                      .copyWith(color: AppColors.textGray),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: 저장 완료 ──────────────────────────────────────────────────────

class _SavedView extends StatelessWidget {
  const _SavedView({required this.book, required this.onOpenApp});

  final BookItem book;
  final VoidCallback onOpenApp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('읽고 싶은 책이 저장되었어요!'),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.backgroundWhite,
          child: Row(
            children: [
              _cover(book.cover, width: 56, height: 80),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: AppTypography.wantedSansBookTitle
                          .copyWith(color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author,
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _PrimaryButton(label: '저장한 책 보러가기', onTap: onOpenApp),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

// ── 오류 ───────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.kind,
    required this.onOpenApp,
    required this.onClose,
  });

  final ShareImportError kind;
  final VoidCallback onOpenApp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (title, guide) = switch (kind) {
      ShareImportError.imageFailed => (
          '이미지를 불러오지 못했어요.',
          '다른 사진으로 다시 시도해주세요.',
        ),
      ShareImportError.noText => (
          '사진에서 글자를 찾지 못했어요.',
          '※ 책 제목이 명확하게 보이는 사진으로 다시 시도해주세요.',
        ),
      ShareImportError.noResult => (
          '일치하는 책을 찾지 못했어요.',
          '※ 책 제목이 명확하게 보이는 사진으로 다시 시도해주세요.',
        ),
      ShareImportError.network => (
          '문제가 발생했어요.',
          '네트워크 연결을 확인하고 다시 시도해주세요.',
        ),
      ShareImportError.notLoggedIn => (
          '로그인이 필요해요.',
          '모아북 앱에서 로그인 후 다시 시도해주세요.',
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(title),
        const SizedBox(height: 12),
        Text(
          guide,
          style: AppTypography.wantedSansBodySmall
              .copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 32),
        Center(
          child: kind == ShareImportError.notLoggedIn
              ? _PrimaryButton(label: '모아북 열기', onTap: onOpenApp)
              : _PrimaryButton(label: '닫기', onTap: onClose),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── 공용 ───────────────────────────────────────────────────────────────────

Widget _cover(String url, {required double width, required double height}) {
  if (url.isEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: const Icon(Icons.book, color: AppColors.textGray),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.book, color: AppColors.textGray),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: AppColors.primary,
        child: Text(
          label,
          style: AppTypography.dungGeunMoBody
              .copyWith(color: AppColors.textWhite),
        ),
      ),
    );
  }
}
