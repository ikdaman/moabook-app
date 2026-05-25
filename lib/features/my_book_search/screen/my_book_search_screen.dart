import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/store_book.dart';
import '../../../features/home/provider/home_provider.dart';

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
      setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        border: Border.all(color: AppColors.borderBlack),
                      ),
                      child: TextField(
                        controller:     _ctrl,
                        onSubmitted:    (_) => _search(),
                        textInputAction: TextInputAction.search,
                        style: AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText:  '내 책 검색',
                          hintStyle: AppTypography.dungGeunMoBody
                              .copyWith(color: AppColors.textHint),
                          border:    InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _search,
                    child: const Icon(Icons.search,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text('검색 결과가 없습니다.',
                              style: AppTypography.dungGeunMoSubtitle
                                  .copyWith(color: AppColors.textPrimary)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final b = _results[i];
                            return GestureDetector(
                              onTap: () =>
                                  context.push(Routes.bookInfo(b.mybookId)),
                              child: Container(
                                margin:  const EdgeInsets.only(bottom: 8),
                                color:   AppColors.backgroundWhite,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    if (b.coverImage != null)
                                      CachedNetworkImage(
                                          imageUrl: b.coverImage!,
                                          width: 50, height: 70,
                                          fit: BoxFit.cover)
                                    else
                                      Container(
                                          width: 50, height: 70,
                                          color: AppColors.surfaceGray),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(b.title,
                                              style: AppTypography
                                                  .wantedSansBookTitle
                                                  .copyWith(
                                                      color: AppColors
                                                          .textPrimary),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          Text(b.author.join(', '),
                                              style: AppTypography
                                                  .wantedSansBodySmall
                                                  .copyWith(
                                                      color:
                                                          AppColors.textGray),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
