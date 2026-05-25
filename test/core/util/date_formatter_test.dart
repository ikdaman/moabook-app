import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/util/date_formatter.dart';

void main() {
  group('DateFormatter.toShortDate', () {
    test('ISO 날짜를 YYMMdd 포맷으로 변환', () {
      expect(DateFormatter.toShortDate('2026-03-30'), '260330');
      expect(DateFormatter.toShortDate('2021-05-04'), '210504');
    });

    test('ISO datetime 도 처리', () {
      expect(DateFormatter.toShortDate('2026-03-30T12:34:56'), '260330');
      expect(DateFormatter.toShortDate('2026-03-30T12:34:56.789Z'), '260330');
    });

    test('잘못된 입력은 빈 문자열', () {
      expect(DateFormatter.toShortDate(null), '');
      expect(DateFormatter.toShortDate(''), '');
      expect(DateFormatter.toShortDate('garbage'), '');
    });

    test('YY.MM.DD 점 표기도 정규화', () {
      expect(DateFormatter.toShortDate('26.03.30'), '260330');
    });

    test('YYYY.MM.DD 점 표기도 처리', () {
      expect(DateFormatter.toShortDate('2026.03.30'), '260330');
    });
  });
}
