import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/home/provider/home_provider.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../../../shared/widgets/title_bar.dart';

class MyBookSearchScreen extends ConsumerStatefulWidget {
  const MyBookSearchScreen({super.key});

  @override
  ConsumerState<MyBookSearchScreen> createState() =>
      _MyBookSearchScreenState();
}

class _MyBookSearchScreenState extends ConsumerState<MyBookSearchScreen> {
  final _ctrl = TextEditingController();
  List<StoreBookItem> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final ds = ref.read(myBookDataSourceProvider);
      final results = await ds.searchMyBooks(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  static (String label, Color color) _tagFor(String status) {
    switch (status.toUpperCase()) {
      case 'INPROGRESS':
        return ('읽는 중', AppColors.statusReading);
      case 'DONE':
      case 'COMPLETED':
        return ('완독', AppColors.statusDone);
      case 'TODO':
      default:
        return ('읽고 싶은 책', AppColors.statusWish);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(
              title: '내 책 검색',
              showBackButton: true,
              onBack: () => context.pop(),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                height: 48,
                child: PixelShadowBox(
                  backgroundColor: AppColors.backgroundWhite,
                  shadowOffset: 2,
                  contentAlignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: TextField(
                            controller: _ctrl,
                            onSubmitted: (_) => _search(),
                            textInputAction: TextInputAction.search,
                            style: AppTypography.dungGeunMoBody
                                .copyWith(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '검색어를 입력하세요',
                              hintStyle: AppTypography.dungGeunMoBody
                                  .copyWith(color: AppColors.textHint),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _search,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(
                            'assets/images/search.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                                AppColors.textPrimary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const RetroLoading(fillBackground: false)
                  : ListView.separated(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _ResultItem(
                        item: _results[i],
                        onTap: () => context
                            .push(Routes.bookInfo(_results[i].mybookId)),
                        tagFor: _tagFor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final StoreBookItem item;
  final VoidCallback onTap;
  final (String, Color) Function(String) tagFor;

  const _ResultItem({
    required this.item,
    required this.onTap,
    required this.tagFor,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = tagFor(item.readingStatus ?? 'TODO');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              height: 112,
              child: item.coverImage != null
                  ? CachedNetworkImage(
                      imageUrl: item.coverImage!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                          color: AppColors.backgroundWhite,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.borderBlack))),
                      errorWidget: (_, _, _) => Container(
                          color: AppColors.backgroundWhite,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.borderBlack))),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        border: Border.all(color: AppColors.borderBlack),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Text(
                      label,
                      style: AppTypography.dungGeunMoTag
                          .copyWith(color: AppColors.textWhite),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: AppTypography.wantedSansBookTitle
                        .copyWith(color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.author.join(', '),
                    style: AppTypography.wantedSansBodySmall
                        .copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
