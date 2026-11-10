import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook/shared/widgets/root_back_guard.dart';

void main() {
  testWidgets('Android always delegates native back to Flutter guards', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    handleAppNavigationNotification(
      const NavigationNotification(canHandlePop: false),
    );
    await tester.pump();
    expect(calls.single.method, 'SystemNavigator.setFrameworkHandlesBack');
    expect(calls.single.arguments, true);
  });

  for (final inShell in [false, true]) {
    testWidgets('root back requires confirmation (shell: $inShell)', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final route = GoRoute(
        path: '/',
        builder: (_, _) =>
            const RootBackGuard(child: Scaffold(body: Text('로그인'))),
      );
      final router = GoRouter(
        routes: [
          if (inShell)
            ShellRoute(builder: (_, _, child) => child, routes: [route])
          else
            route,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      int exits() =>
          calls.where((call) => call.method == 'SystemNavigator.pop').length;
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits(), 0);
      expect(find.text('뒤로가기를 한 번 더 누르면 종료돼요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits(), 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exits(), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('root signup back returns to login', (tester) async {
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/signup',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('로그인')),
        ),
        GoRoute(
          path: '/signup',
          builder: (_, _) => RootBackGuard(
            onBack: () => router.go('/'),
            child: const Scaffold(body: Text('회원가입')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsNothing);
  });
}
