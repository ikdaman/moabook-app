/// Android 원본의 [project.side.ui.util.DateFormatter] 와 동등.
/// 모든 화면이 동일한 표기(`YYMMdd`)를 쓰도록 강제한다.
///
/// 입력으로 ISO `YYYY-MM-DD`, ISO datetime, 또는 이미 변환된
/// `YY.MM.DD` / `YYYY.MM.DD` 모두 허용.
///
/// 서버 datetime 은 UTC 저장이므로, 시간 정보가 포함된 값은
/// 기기 로컬 타임존으로 변환한 뒤 날짜를 뽑는다.
/// 날짜만 있는 값(`YYYY-MM-DD` 등)은 타임존 개념이 없으므로 그대로 쓴다.
abstract final class DateFormatter {
  static final _pattern = RegExp(r'^(\d{2,4})[-.](\d{2})[-.](\d{2})');
  static final _offsetSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// 서버 날짜 문자열 → 로컬 [DateTime].
  ///
  /// datetime 이면 오프셋 표기(`Z`, `+09:00`)가 없어도 UTC 로 간주해
  /// 로컬로 변환한다. 날짜만 있으면 해당 일자의 로컬 자정.
  /// 2자리 연도(`YY.MM.DD`)는 세기를 알 수 없어 null.
  static DateTime? parseToLocal(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.contains('T')) {
      final normalized = _offsetSuffix.hasMatch(value) ? value : '${value}Z';
      return DateTime.tryParse(normalized)?.toLocal();
    }
    final m = _pattern.firstMatch(value);
    if (m == null || m.group(1)!.length != 4) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  static String toShortDate(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains('T')) {
      final local = parseToLocal(value);
      if (local == null) return '';
      return '${(local.year % 100).toString().padLeft(2, '0')}'
          '${local.month.toString().padLeft(2, '0')}'
          '${local.day.toString().padLeft(2, '0')}';
    }
    final m = _pattern.firstMatch(value);
    if (m == null) return '';
    final yearRaw = m.group(1)!;
    final month   = m.group(2)!;
    final day     = m.group(3)!;
    final year    = yearRaw.length == 4 ? yearRaw.substring(2) : yearRaw;
    return '$year$month$day';
  }

  /// 로컬 기준 `YYYY-MM-DD`. 네이티브 위젯 등으로 날짜를 넘길 때 사용.
  /// 변환 불가한 입력은 원문 그대로 반환한다.
  static String toIsoLocalDate(String? value) {
    final local = parseToLocal(value);
    if (local == null) return value ?? '';
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
