// test/features/onboarding/onboarding_route_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/router/routes.dart';

void main() {
  test('온보딩 경로 상수 존재', () {
    expect(Routes.onboarding, '/onboarding');
  });
}
