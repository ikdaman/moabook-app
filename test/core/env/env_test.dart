import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/env/env.dart';

void main() {
  test('Env.baseUrl has default value', () {
    expect(Env.baseUrl, 'https://moabook.shop');
  });
}
