import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

void main() {
  Future<(GoRouter, ReadingWorkspaceState, List<MethodCall>)> mount(
    WidgetTester tester, {
    String screen = 'shelf',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
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
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => ReadingWorkspace(
                embedded: true,
                initialMood: Mood.a,
                initialScreen: screen,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('다른 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return (
      router,
      tester.state<ReadingWorkspaceState>(find.byType(ReadingWorkspace)),
      calls,
    );
  }

  testWidgets(
    'Android back closes first-record sheet before leaving the card',
    (tester) async {
      final (_, state, calls) = await mount(tester, screen: 'card-empty');
      await tester.tap(find.text('첫 기록 남기기'));
      await tester.pumpAndSettle();
      expect(state.screen, 'record-options');
      await tester.ensureVisible(find.text('자유 기록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자유 기록'));
      await tester.pumpAndSettle();
      expect(state.screen, 'record-free');
      state.go('date-picker');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.screen, 'record-free');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.screen, 'record-options');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.screen, 'card-empty');
      expect(find.text('첫 기록 남기기'), findsOneWidget);
      expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.screen, 'shelf');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home requires a second back within two seconds and resets after navigation',
    (tester) async {
      final (_, state, calls) = await mount(tester);
      int exits() =>
          calls.where((c) => c.method == 'SystemNavigator.pop').length;
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('뒤로가기를 한 번 더 누르면 종료돼요.'), findsOneWidget);
      expect(exits(), 0);
      await tester.pump(const Duration(seconds: 3));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits(), 0);
      state.go('add-options');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.screen, 'shelf');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits(), 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exits(), 1);
    },
  );

  testWidgets('pushed screens receive back without changing the library', (
    tester,
  ) async {
    final (router, state, calls) = await mount(tester);
    router.push('/other');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('다른 화면'), findsNothing);
    expect(state.screen, 'shelf');
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
  });

  testWidgets('system back is consumed while a write is in progress', (
    tester,
  ) async {
    final (_, state, calls) = await mount(tester, screen: 'card-empty');
    state.go('record-options');
    await tester.pumpAndSettle();
    // The async write keeps this guard active until the request completes.
    state.isSaving = true;
    tester.element(find.byType(ReadingWorkspace)).markNeedsBuild();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(state.screen, 'record-options');
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
    state.isSaving = false;
    tester.element(find.byType(ReadingWorkspace)).markNeedsBuild();
    await tester.pumpAndSettle();
  });

  testWidgets('sheets slide up on open and down on dismiss', (tester) async {
    final (_, state, _) = await mount(tester, screen: 'card-empty');
    state.go('record-options');
    await tester.pump();
    final title = find.text('기록 추가');
    final start = tester.getTopLeft(title).dy;
    await tester.pump(const Duration(milliseconds: 100));
    final middle = tester.getTopLeft(title).dy;
    await tester.pumpAndSettle();
    final end = tester.getTopLeft(title).dy;
    expect(start, greaterThan(middle));
    expect(middle, greaterThan(end));
    state.back();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(title).dy, greaterThan(end));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
  });
}
