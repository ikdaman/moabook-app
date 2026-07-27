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

/// OCR 검색 쿼리 하나. [byKeyword]면 알라딘 Keyword(제목+저자) 검색으로 호출.
class OcrQuery {
  final String text;
  final bool byKeyword;
  const OcrQuery(this.text, {this.byKeyword = false});
}

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
    queries.map(
      (q) => aladin
          .searchByTitle(q.text, byKeyword: q.byKeyword)
          .catchError((Object _) => <BookItem>[]),
    ),
  );

  return mergeCoverSearchResults(resultLists);
}

/// "손원평 지음", "베르나르 베르베르 옮김" — 작가명 라인 확정 패턴(접미형).
/// 이런 라인은 제목일 수 없으므로 제목 쿼리에서 제외한다.
final _strongAuthorLine = RegExp(r'^([가-힣][가-힣·\s]{0,12}[가-힣])\s*(지음|지은이|옮김|엮음|그림|글|저)$');

/// "지은이 에이핫", "옮긴이 장소미" — 접두형 작가 라인. 접미형과 동급 확정.
final _prefixAuthorLine = RegExp(r'^(지은이|지음|글|그림|옮긴이|엮은이)\s+([가-힣][가-힣·\s]{0,12}[가-힣])$');

/// "김호연 장편소설" — 작가명+장르 패턴. 작가는 추출하되,
/// 드물게 제목 일부일 수도 있어 제목 쿼리로도 유지한다.
final _genreAuthorLine = RegExp(r'^([가-힣][가-힣·\s]{0,12}[가-힣])\s+(장편소설|소설|산문집|시집|에세이)$');

bool _isAuthorOnlyLine(String trimmed) =>
    _strongAuthorLine.hasMatch(trimmed) || _prefixAuthorLine.hasMatch(trimmed);

/// OCR 후보 전체에서 작가명을 찾는다. (작가 라인은 글자가 작아
/// 점수 하위로 밀리는 경우가 많아 candidateCount 제한 없이 훑는다.)
String? extractOcrAuthor(List<String> candidateTexts) {
  for (final raw in candidateTexts) {
    final t = raw.trim();
    final suffix = _strongAuthorLine.firstMatch(t);
    if (suffix != null) return suffix.group(1)!.trim();
    final prefix = _prefixAuthorLine.firstMatch(t);
    if (prefix != null) return prefix.group(2)!.trim();
    final genre = _genreAuthorLine.firstMatch(t);
    if (genre != null) return genre.group(1)!.trim();
  }
  return null;
}

/// OCR 후보 텍스트들을 알라딘 검색 쿼리 집합으로 변환.
///
/// - 작가명 라인("○○○ 지음" 등)을 찾으면 `제목 작가` Keyword 쿼리를
///   최우선으로 추가한다 — 인식이 부정확해도 두 단서가 겹치면 적중률↑.
/// - 상위 [candidateCount]개 후보만 제목 쿼리로 사용.
/// - 각 후보에서 `원문` + `정제 변형`을 생성. 정제는 괄호 안 부가정보
///   (저자/부제)와 장식 기호(『』, 하이픈 등)를 제거해 순수 제목에 가깝게 만든다.
///   예) `여름(김애란)` → `여름`,  `-모순(양귀자/소설)` → `모순`
/// - 중복 제거 후 최대 [maxQueries]개로 제한.
List<OcrQuery> buildOcrQueries(
  List<String> candidateTexts, {
  int candidateCount = searchCandidateCount,
  int queryLimit = maxQueries,
}) {
  final author = extractOcrAuthor(candidateTexts);
  // 작가 확정 라인은 제목 후보에서 제외 (장르 패턴은 유지).
  final titleTexts = candidateTexts
      .where((t) => !_isAuthorOnlyLine(t.trim()))
      .toList();

  final seen = <String>{};
  final queries = <OcrQuery>[];

  // 1) 제목+작가 결합 Keyword 쿼리 — 상위 2개 제목 후보의 정제본 기준.
  //    외국어 원제가 상위를 차지하는 표지(번역서) 대비, 상위권 첫 한글
  //    후보도 결합 대상에 추가한다.
  if (author != null) {
    final combineSources = titleTexts.take(2).toList();
    final hangul = RegExp(r'[가-힣]');
    for (final t in titleTexts.take(candidateCount)) {
      if (hangul.hasMatch(t) && !combineSources.contains(t)) {
        combineSources.add(t);
        break;
      }
    }
    for (final raw in combineSources) {
      // 장르 패턴 라인("김호연 장편소설")은 결합 기반으로 부적절.
      if (_genreAuthorLine.hasMatch(raw.trim())) continue;
      final variants = _variantsOf(raw);
      if (variants.isEmpty) continue;
      final title = variants.last; // 정제본이 있으면 정제본, 없으면 원문
      if (title == author) continue;
      final combined = '$title $author';
      if (seen.add(combined) && queries.length < queryLimit) {
        queries.add(OcrQuery(combined, byKeyword: true));
      }
    }
  }

  // 2) 제목 단독 쿼리.
  for (final raw in titleTexts.take(candidateCount)) {
    for (final v in _variantsOf(raw)) {
      if (seen.add(v)) {
        queries.add(OcrQuery(v));
        if (queries.length >= queryLimit) return queries;
      }
    }
  }
  return queries;
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
