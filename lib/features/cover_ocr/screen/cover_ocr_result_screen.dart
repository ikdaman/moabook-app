// 사진 검색 결과 화면
//
// 촬영/갤러리 → OCR → 알라딘 검색까지 끝낸 뒤, 촬영한 사진 미리보기와
// 결과 목록을 표시한다. "다시 찍기"는 pop 으로 촬영 화면에 돌아간다.
// 카메라 로직 없음(순수 표시).

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../book_search/provider/book_search_provider.dart';

/// 촬영 화면 → 결과 화면으로 넘기는 인자 묶음.
class CoverOcrResultArgs {
  const CoverOcrResultArgs({required this.imagePath, required this.results});

  final String imagePath;
  final List<BookItem> results;
}

class CoverOcrResultScreen extends ConsumerWidget {
  const CoverOcrResultScreen({
    super.key,
    required this.imagePath,
    required this.results,
  });

  final String imagePath;
  final List<BookItem> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = results.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDefault,
        title: Text(
          '사진 검색',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _photoPreview(context),
          const SizedBox(height: 16),
          Text(
            isEmpty
                ? '※ 책 제목이 명확하게 보이는 사진을 업로드해 주세요.'
                : '※ 사진에 텍스트가 많은 경우, 알맞은 결과가 하단에 보일 수 있어요.',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          if (isEmpty)
            Text(
              '없음',
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: AppColors.textGray),
            )
          else
            ...results.map((book) => _bookCard(context, ref, book)),
        ],
      ),
    );
  }

  /// 촬영한 사진 썸네일 (가운데 정렬).
  Widget _photoPreview(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 160,
            width: 120,
            child: Icon(Icons.image_not_supported_outlined),
          ),
        ),
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
          style: AppTypography.wantedSansBookTitle
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
