// 표지 이미지 경로 → OCR 제목 후보 → 알라딘 검색 결과 병합.
//
// 바코드 화면과 OCR 실험 화면이 공유하는 1회성 검색 로직.
// (실시간 아님 — 촬영 1장당 OCR 1회 + 알라딘 최대 [candidateCount]콜)

import '../../../domain/model/book_item.dart';
import '../../../data/datasource/aladin_datasource.dart';
import 'book_cover_ocr.dart';

/// 검색에 사용할 상위 후보 개수. 이 수만큼만 알라딘을 호출한다.
const _searchCandidateCount = 3;

/// 후보별로 사용할 상위 결과 수 — 하위 결과는 관련성이 낮음.
const _perCandidateLimit = 10;

/// 표지 이미지 경로를 받아 검색 결과 책 목록을 반환.
/// 텍스트를 못 읽으면 빈 리스트.
Future<List<BookItem>> searchBooksByCover(
  String imagePath,
  AladinDataSource aladin,
) async {
  final candidates = await recognizeBookCover(imagePath);
  if (candidates.isEmpty) return [];

  final top = candidates.take(_searchCandidateCount).toList();
  final resultLists = await Future.wait(
    top.map((c) => aladin.searchByTitle(c.text).catchError(
          (Object _) => <BookItem>[],
        )),
  );

  final seen = <int>{};
  final merged = <BookItem>[];
  for (final list in resultLists) {
    for (final book in list.take(_perCandidateLimit)) {
      if (seen.add(book.itemId)) merged.add(book);
    }
  }
  return merged;
}
