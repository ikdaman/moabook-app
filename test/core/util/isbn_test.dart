import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/util/isbn.dart';

void main() {
  test('book barcodes require a valid prefix, length and check digit', () {
    expect(isBookIsbn13('9788966260959'), isTrue);
    expect(isBookIsbn13('9788966260950'), isFalse);
    expect(isBookIsbn13('8801234567893'), isFalse);
    expect(isBookIsbn13('12345'), isFalse);
    expect(isBookIsbn13('978896626095X'), isFalse);
    expect(isBookIsbn13(null), isFalse);
  });
}
