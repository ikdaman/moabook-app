import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

void main() {
  testWidgets(
    'basic shelf captures every spine page and restores the current page',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ReadingWorkspace(initialMood: Mood.a, initialScreen: 'shelf'),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ReadingWorkspaceState>(
        find.byType(ReadingWorkspace),
      );
      state.library
        ..clear()
        ..addEntries(
          List.generate(
            50,
            (i) => MapEntry(
              '$i',
              ReadingBook('$i', '책 $i', '작가', '', '', '', totalPage: 300),
            ),
          ),
        );
      state.go('shelf');
      await tester.pumpAndSettle();
      expect(state.shelfPageCount, greaterThan(1));
      final capture = find.byKey(state.shelfCaptureKey);
      for (final label in ['서가', '책 추가', 'MOABOOK / MY BOOKS']) {
        expect(
          find.descendant(of: capture, matching: find.text(label)),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: capture, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: capture,
          matching: find.byKey(const Key('shelf-page-indicator')),
        ),
        findsNothing,
      );
      expect(find.text('책 추가'), findsOneWidget);
      expect(find.byKey(const Key('shelf-page-indicator')), findsOneWidget);
      state.shelfPages.jumpToPage(1);
      await tester.pumpAndSettle();
      final expectedPage = state.shelfPage;
      ReadingImageExport? result;
      Object? error;
      state.captureShelfImages().then(
        (value) => result = value,
        onError: (Object value) => error = value,
      );
      for (var i = 0; i < 200 && result == null && error == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(error, isNull);
      expect(result, isNotNull);
      expect(result!.pageCount, state.shelfPageCount);
      expect(result!.books.map((book) => book.id), state.library.keys);
      expect(state.shelfPage, expectedPage);
      await tester.pumpAndSettle();
      expect(state.shelfPages.page, expectedPage.toDouble());
      await tester.runAsync(() async {
        for (final page in result!.shelfPages) {
          final codec = await ui.instantiateImageCodec(page.png);
          final image = (await codec.getNextFrame()).image;
          expect(image.width, 1080);
          expect(image.height, greaterThan(image.width));
          final rgba = await image.toByteData();
          expect(
            rgba!.getUint8(3),
            255,
            reason: 'Shelf background must be opaque',
          );
          image.dispose();
          codec.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
