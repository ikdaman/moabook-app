import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/util/html_text.dart';

void main() {
  group('decodeHtmlEntities', () {
    test('null → null', () {
      expect(decodeHtmlEntities(null), null);
    });

    test('빈 문자열 → 빈 문자열', () {
      expect(decodeHtmlEntities(''), '');
    });

    test('엔티티 없는 평문 → 그대로', () {
      expect(decodeHtmlEntities('이것은 평문'), '이것은 평문');
    });

    test('&lt; / &gt; / &amp; 디코딩', () {
      expect(decodeHtmlEntities('a &lt; b &amp; c &gt; d'), 'a < b & c > d');
    });

    test('&quot; / &#39; 디코딩', () {
      expect(
        decodeHtmlEntities('&quot;Hello&quot; &#39;world&#39;'),
        '"Hello" \'world\'',
      );
    });

    test('실제 알라딘 description 케이스 (꺾쇠/앰퍼샌드 혼합)', () {
      const input = '삶 &lt;변하지 않는 것&gt; &amp; 책 소개';
      expect(decodeHtmlEntities(input), '삶 <변하지 않는 것> & 책 소개');
    });

    test('숫자 엔티티 (decimal) — &#9824;', () {
      expect(decodeHtmlEntities('&#9824;'), '♠');
    });
  });
}
