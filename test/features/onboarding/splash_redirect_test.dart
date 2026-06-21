import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/domain/repository/auth_repository.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/splash/screen/splash_screen.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<bool> isLoggedIn() async => false;

  // 나머지 멤버는 noSuchMethod 로 처리(테스트 미사용).
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('미로그인 시 온보딩으로 이동', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.splash,
      routes: [
        GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: Routes.onboarding,
            builder: (_, __) => const Scaffold(body: Text('ONBOARDING'))),
        GoRoute(
            path: Routes.home,
            builder: (_, __) => const Scaffold(body: Text('HOME'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ONBOARDING'), findsOneWidget);
  });
}
