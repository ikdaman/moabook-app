import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

void main() {
  for (final width in [320.0, 402.0]) {
    testWidgets('collection capture preserves screen proportions at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ReadingWorkspace(
          initialMood: Mood.a,
          initialScreen: 'collection',
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ReadingWorkspaceState>(
        find.byType(ReadingWorkspace),
      );
      final collection = state.currentCollection;
      final boundary = find.byKey(state.collectionCaptureKeys[collection.id]!);
      final firstSlot = find.descendant(
        of: boundary,
        matching: find.byKey(const ValueKey('collection-slot-0')),
      );
      final originalSlotSize = tester.getSize(firstSlot);
      final originalGridTop = tester.getTopLeft(firstSlot).dy;
      ReadingImageExport? result;
      Object? error;
      state
          .captureCollectionImage(collection)
          .then(
            (value) => result = value,
            onError: (Object value) => error = value,
          );
      await tester.pump();
      expect(
        find.descendant(of: boundary, matching: find.text(collection.name)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: boundary, matching: find.text('편집')),
        findsNothing,
      );
      expect(
        find.descendant(of: boundary, matching: find.text('이미지 저장')),
        findsNothing,
      );
      expect(tester.getSize(firstSlot), originalSlotSize);
      expect(tester.getTopLeft(firstSlot).dy, lessThan(originalGridTop));
      final captureSize = tester.getSize(boundary);
      for (var i = 0; i < 200 && result == null && error == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(error, isNull);
      expect(result, isNotNull);
      expect(result!.title, collection.name);
      expect(
        result!.collectionSlots!.map((book) => book?.id),
        collection.slots,
      );
      expect(result!.collectionPng, isNotNull);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(result!.collectionPng!);
        final image = (await codec.getNextFrame()).image;
        try {
          expect(image.width, 1080);
          final expectedHeight = (captureSize.height + 44) * 1080 / width;
          expect(image.height, closeTo(expectedHeight, 2));
        } finally {
          image.dispose();
          codec.dispose();
        }
      });
      await tester.pumpAndSettle();
      expect(state.capturingCollectionId, isNull);
      expect(
        find.descendant(of: boundary, matching: find.text('편집')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(firstSlot).dy, originalGridTop);
      expect(tester.takeException(), isNull);
    });
  }
}
