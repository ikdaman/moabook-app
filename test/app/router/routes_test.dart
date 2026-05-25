import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/router/routes.dart';

void main() {
  test('splash is root path', () {
    expect(Routes.splash, '/');
  });
  test('bookInfo generates correct path', () {
    expect(Routes.bookInfo(42), '/main/book-info/42');
  });
  test('bookInfo with 0 generates path', () {
    expect(Routes.bookInfo(0), '/main/book-info/0');
  });
}
