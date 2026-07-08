// 표지 OCR 검색 결과 화면
//
// 바코드 화면에서 표지를 촬영 → OCR → 알라딘 검색까지 끝낸 뒤,
// 이 화면에 결과 목록만 표시한다. 카메라 로직 없음(순수 표시).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../book_search/provider/book_search_provider.dart';

class CoverOcrResultScreen extends ConsumerWidget {
  const CoverOcrResultScreen({super.key, required this.results});

  final List<BookItem> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDefault,
        title: Text(
          '표지 검색 결과',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: results.isEmpty
          ? Center(
              child: Text(
                '표지에서 책을 찾지 못했어요.\n바코드 스캔을 이용해 주세요.',
                style: AppTypography.dungGeunMoBody
                    .copyWith(color: AppColors.textGray),
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '검색 결과 ${results.length}권',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                ...results.map((book) => _bookCard(context, ref, book)),
              ],
            ),
    );
  }

  Widget _bookCard(BuildContext context, WidgetRef ref, BookItem book) {
    return Card(
      color: AppColors.backgroundWhite,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: book.cover.isEmpty
            ? const SizedBox(width: 44, child: Icon(Icons.book))
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: book.cover,
                  width: 44,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          book.title,
          style: AppTypography.dungGeunMoBody
              .copyWith(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          book.author,
          style: AppTypography.wantedSansCaption
              .copyWith(color: AppColors.textGray),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          ref.read(bookSearchProvider.notifier).selectBook(book);
          context.push(Routes.addBook);
        },
      ),
    );
  }
}
