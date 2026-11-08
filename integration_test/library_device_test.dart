import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moabook/features/reading/provider/reading_gateway_provider.dart';
import 'package:moabook/app/theme/app_theme.dart';
import 'package:moabook/features/reading/screen/reading_library_screen.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const live = bool.fromEnvironment('LIVE_ACCOUNT_QA');
  testWidgets('device shelf paging and boundary transitions', (tester) async {
    await tester.pumpWidget(
      live
          ? const ProviderScope(
              child: MaterialApp(
                builder: fixedAppTextScale,
                home: ReadingLibraryScreen(),
              ),
            )
          : const DesignPreviewApp(),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final finder = find.byType(ReadingWorkspace);
      if (finder.evaluate().isNotEmpty) {
        final state = tester.state<ReadingWorkspaceState>(finder);
        if (!live || (state.shelfLoaded && state.collectionsLoaded)) break;
      }
    }
    expect(
      find.byType(ReadingWorkspace),
      findsOneWidget,
      reason:
          'The live-account test requires an existing signed-in session. Log in on the device first.',
    );
    final state = tester.state<ReadingWorkspaceState>(
      find.byType(ReadingWorkspace),
    );
    expect(state.library, isNotEmpty);
    final calls = <String>[];
    if (live) {
      final remote = (state.gateway as AppReadingGateway).remote;
      remote.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(
              options.path,
            ); // Never capture headers, credentials or bodies.
            handler.next(options);
          },
        ),
      );
    }
    await tester.pumpAndSettle();
    Future<void> swipePages() async {
      for (var round = 0; round < 3; round++) {
        for (var page = 1; page < state.shelfPageCount; page++) {
          await tester.drag(
            find.byKey(const Key('shelf-pager')),
            const Offset(-280, 0),
          );
          await tester.pumpAndSettle();
        }
        for (var page = state.shelfPageCount - 1; page > 0; page--) {
          await tester.drag(
            find.byKey(const Key('shelf-pager')),
            const Offset(280, 0),
          );
          await tester.pumpAndSettle();
        }
      }
    }

    if (kProfileMode) {
      await binding.watchPerformance(
        swipePages,
        reportKey: live ? 'authenticated_shelf_swipes' : 'preview_shelf_swipes',
      );
    } else {
      await swipePages();
    }
    expect(
      calls,
      isEmpty,
      reason: 'Internal shelf pages must not fetch API data',
    );
    state.shelfPages.jumpToPage(state.shelfPageCount - 1);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('shelf-pager')),
      const Offset(-280, 0),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && state.collectionsLoading; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.screen, 'collection');
    expect(state.collectionPage, 0);
    await tester.drag(
      find.byKey(const Key('collection-pager')),
      const Offset(280, 0),
    );
    await tester.pumpAndSettle();
    expect(state.screen, 'shelf');
    expect(state.shelfPage, state.shelfPageCount - 1);
    expect(tester.takeException(), isNull);
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['platform'] = defaultTargetPlatform.name;
    binding.reportData!['buildMode'] = kProfileMode ? 'profile' : 'debug';
    binding.reportData!['library'] = {
      'live': live,
      'books': state.library.length,
      'pages': state.shelfPageCount,
      'boundaryRefreshPaths': calls,
    };
  });
}
