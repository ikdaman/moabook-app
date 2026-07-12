// 표지 이미지 경로 → OCR 제목 후보 → 알라딘 검색 결과 병합.
//
// 바코드 화면과 OCR 실험 화면이 공유하는 1회성 검색 로직.
// (실시간 아님 — 촬영 1장당 OCR 1회 + 알라딘 최대 [maxQueries]콜)

import '../../../domain/model/book_item.dart';
import '../../../data/datasource/aladin_datasource.dart';
import 'book_cover_ocr.dart';

/// 쿼리 생성에 사용할 상위 후보 개수. (오버레이 자막이 상위를 차지해도
/// 실제 제목이 3~5위로 밀리는 경우가 많아 3 → 5로 확대.)
const searchCandidateCount = 5;

/// 알라딘 호출 상한 — 후보별 변형까지 합쳐 과다 호출을 막는다.
const maxQueries = 8;

/// 쿼리별로 사용할 상위 결과 수 — 하위 결과는 관련성이 낮음.
const _perQueryLimit = 10;

/// 표지 이미지 경로를 받아 검색 결과 책 목록을 반환.
/// 텍스트를 못 읽으면 빈 리스트.
Future<List<BookItem>> searchBooksByCover(
  String imagePath,
  AladinDataSource aladin,
) async {
  final candidates = await recognizeBookCover(imagePath);
  if (candidates.isEmpty) return [];

  final queries = buildOcrQueries(candidates.map((c) => c.text).toList());
  final resultLists = await Future.wait(
    queries.map((q) => aladin.searchByTitle(q).catchError(
          (Object _) => <BookItem>[],
        )),
  );

  return mergeCoverSearchResults(resultLists);
}

/// OCR 후보 텍스트들을 알라딘 검색 쿼리 집합으로 변환.
///
/// - 상위 [candidateCount]개 후보만 사용.
/// - 각 후보에서 `원문` + `정제 변형`을 생성. 정제는 괄호 안 부가정보
///   (저자/부제)와 장식 기호(『』, 하이픈 등)를 제거해 순수 제목에 가깝게 만든다.
///   예) `여름(김애란)` → `여름`,  `-모순(양귀자/소설)` → `모순`
/// - 중복 제거 후 최대 [maxQueries]개로 제한.
List<String> buildOcrQueries(
  List<String> candidateTexts, {
  int candidateCount = searchCandidateCount,
  int queryLimit = maxQueries,
}) {
  final queries = <String>{};
  for (final raw in candidateTexts.take(candidateCount)) {
    for (final v in _variantsOf(raw)) {
      queries.add(v);
      if (queries.length >= queryLimit) return queries.toList();
    }
  }
  return queries.toList();
}

/// 후보 한 줄에서 검색 쿼리 변형(원문 + 정제본)을 만든다.
List<String> _variantsOf(String raw) {
  final out = <String>[];
  final t = raw.trim();
  if (t.length < 2) return out;
  out.add(t);

  final cleaned = t
      // 괄호류 안 내용 제거: (…) （…） 【…】 [...]
      .replaceAll(RegExp(r'[（(【\[][^）)】\]]*[)）】\]]?'), ' ')
      // 한글 따옴표/겹화살괄호 제거
      .replaceAll(RegExp(r'[『』「」《》〈〉]'), ' ')
      // 일반 따옴표 제거
      .replaceAll(RegExp(r'''["'`]'''), ' ')
      // 장식 기호 제거
      .replaceAll(RegExp(r'[·•\-–—_/\\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.length >= 2 && cleaned != t) out.add(cleaned);
  return out;
}

/// 여러 쿼리의 결과를 **라운드로빈**으로 병합(itemId 기준 중복 제거).
///
/// 쿼리 순서대로 이어붙이면(concat) 상위 후보=오버레이 자막의 잡탕 결과가
/// 앞을 독식해 정작 제목 매칭 결과가 아래로 묻힌다. 대신 각 쿼리의 N번째
/// 결과를 한 바퀴씩 돌며 뽑으면(1위끼리 → 2위끼리 …) 어느 쿼리든 정확히
/// 맞은 책이 상단에 노출된다.
List<BookItem> mergeCoverSearchResults(List<List<BookItem>> resultLists) {
  final capped =
      resultLists.map((l) => l.take(_perQueryLimit).toList()).toList();
  final maxLen =
      capped.fold<int>(0, (m, l) => l.length > m ? l.length : m);

  final seen = <int>{};
  final merged = <BookItem>[];
  for (var col = 0; col < maxLen; col++) {
    for (final list in capped) {
      if (col < list.length && seen.add(list[col].itemId)) {
        merged.add(list[col]);
      }
    }
  }
  return merged;
}
