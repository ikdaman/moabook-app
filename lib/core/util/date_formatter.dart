/// Android 원본의 [project.side.ui.util.DateFormatter] 와 동등.
/// 모든 화면이 동일한 표기(`YYMMdd`)를 쓰도록 강제한다.
///
/// 입력으로 ISO `YYYY-MM-DD`, ISO datetime, 또는 이미 변환된
/// `YY.MM.DD` / `YYYY.MM.DD` 모두 허용.
abstract final class DateFormatter {
  static final _pattern = RegExp(r'^(\d{2,4})[-.](\d{2})[-.](\d{2})');

  static String toShortDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final m = _pattern.firstMatch(value);
    if (m == null) return '';
    final yearRaw = m.group(1)!;
    final month   = m.group(2)!;
    final day     = m.group(3)!;
    final year    = yearRaw.length == 4 ? yearRaw.substring(2) : yearRaw;
    return '$year$month$day';
  }
}
