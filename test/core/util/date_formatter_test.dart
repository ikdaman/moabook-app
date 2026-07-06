import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/util/date_formatter.dart';

/// 실행 환경 타임존에 의존하지 않도록, datetime 케이스의 기대값은
/// 동일한 UTC→로컬 변환으로 계산한다.
String _shortDateOf(DateTime local) =>
    '${(local.year % 100).toString().padLeft(2, '0')}'
    '${local.month.toString().padLeft(2, '0')}'
    '${local.day.toString().padLeft(2, '0')}';

void main() {
  group('DateFormatter.toShortDate', () {
    test('ISO 날짜(타임존 없음)는 그대로 YYMMdd 변환', () {
      expect(DateFormatter.toShortDate('2026-03-30'), '260330');
      expect(DateFormatter.toShortDate('2021-05-04'), '210504');
    });

    test('ISO datetime 은 UTC 로 간주해 로컬 날짜로 변환', () {
      final expected =
          _shortDateOf(DateTime.parse('2026-03-30T12:34:56Z').toLocal());
      expect(DateFormatter.toShortDate('2026-03-30T12:34:56'), expected);
      expect(DateFormatter.toShortDate('2026-03-30T12:34:56.789Z'), expected);
    });

    test('UTC 늦은 시각은 동부 타임존에서 다음날로 넘어감', () {
      final expected =
          _shortDateOf(DateTime.parse('2026-03-30T23:30:00Z').toLocal());
      expect(DateFormatter.toShortDate('2026-03-30T23:30:00Z'), expected);
      // KST(+9) 환경이면 다음날이어야 한다.
      if (DateTime.now().timeZoneOffset == const Duration(hours: 9)) {
        expect(expected, '260331');
      }
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

  group('DateFormatter.parseToLocal', () {
    test('datetime(Z)은 로컬로 변환', () {
      expect(
        DateFormatter.parseToLocal('2026-03-30T15:00:00Z'),
        DateTime.parse('2026-03-30T15:00:00Z').toLocal(),
      );
    });

    test('오프셋 없는 datetime 은 UTC 로 간주', () {
      expect(
        DateFormatter.parseToLocal('2026-03-30T15:00:00'),
        DateTime.parse('2026-03-30T15:00:00Z').toLocal(),
      );
    });

    test('날짜만 있으면 로컬 자정', () {
      expect(DateFormatter.parseToLocal('2026-03-30'), DateTime(2026, 3, 30));
    });

    test('2자리 연도/쓰레기 입력은 null', () {
      expect(DateFormatter.parseToLocal('26.03.30'), isNull);
      expect(DateFormatter.parseToLocal('garbage'), isNull);
      expect(DateFormatter.parseToLocal(null), isNull);
    });
  });

  group('DateFormatter.toIsoLocalDate', () {
    test('datetime 은 로컬 날짜 문자열로', () {
      final local = DateTime.parse('2026-03-30T23:30:00Z').toLocal();
      final expected = '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(DateFormatter.toIsoLocalDate('2026-03-30T23:30:00Z'), expected);
    });

    test('날짜만 있으면 그대로', () {
      expect(DateFormatter.toIsoLocalDate('2026-03-30'), '2026-03-30');
    });

    test('변환 불가 입력은 원문 유지', () {
      expect(DateFormatter.toIsoLocalDate('garbage'), 'garbage');
      expect(DateFormatter.toIsoLocalDate(null), '');
    });
  });
}
