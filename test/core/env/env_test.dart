import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/env/env.dart';

void main() {
  test(
    'current catalog and shelf paths are configured without extra flags',
    () {
      expect(Env.catalogSearchPath, '/books');
      expect(Env.catalogDetailPath, '/books/detail');
      expect(Env.readingShelfPath, '/mybooks');
      expect(Env.readingPageSizeKey, 'limit');
    },
  );
  test('Env.baseUrl has default value', () {
    expect(Env.baseUrl, 'https://moabook.shop');
  });
}
