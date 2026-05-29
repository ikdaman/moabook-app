import 'package:html_unescape/html_unescape_small.dart';

/// HTML 엔티티(`&lt;`, `&gt;`, `&amp;`, `&quot;`, `&#39;`, `&#xNN;` 등) → 평문 문자.
///
/// 알라딘 OpenAPI 응답은 description / title / publisher / author 등에
/// 엔티티 인코딩이 박혀 있어 `Text` 위젯이 그대로 노출한다. 데이터 매핑 시
/// 호출하여 도메인 모델에는 평문만 들어가도록 강제한다.
///
/// `html_unescape_small` 은 ~7KB, 자주 쓰이는 엔티티 집합만 다룬다 (full 본은 5x 크기).
final _unescape = HtmlUnescape();

/// null-safe 디코드. 빈 문자열은 그대로 반환.
String? decodeHtmlEntities(String? input) {
  if (input == null || input.isEmpty) return input;
  return _unescape.convert(input);
}
