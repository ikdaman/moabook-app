// test/features/onboarding/onboarding_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/app/router/routes.dart';
import 'package:moabook/features/onboarding/screen/onboarding_screen.dart';

GoRouter _router() => GoRouter(
      initialLocation: Routes.onboarding,
      routes: [
        GoRoute(
            path: Routes.onboarding,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(
            path: Routes.login,
            builder: (_, __) =>
                const Scaffold(body: Text('LOGIN_SCREEN'))),
      ],
    );

void main() {
  testWidgets('건너뛰기 누르면 로그인으로 이동', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('건너뛰기'), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    // drain router transition + remaining TypingText timers (charInterval=60ms,
    // holdDuration=1000ms max). Use a long enough pump to exhaust all timers.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });
}
