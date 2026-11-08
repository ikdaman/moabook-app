import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

void main() {
  testWidgets('vertical book titles preserve spaces between words', (
    tester,
  ) async {
    const title = '믿음을 의심하다';
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 34,
            height: 200,
            child: VerticalSpineTitle(
              title,
              style: const DesignPalette(Mood.a).text(11, height: 1),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(VerticalSpineTitle),
        matching: find.byType(Text),
      ),
    );
    expect(text.textSpan!.toPlainText().replaceAll('\n', ''), title);
    expect(text.textSpan!.toPlainText(), contains('을\n \n의'));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(VerticalSpineTitle),
        matching: find.byType(RichText),
      ),
    );
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: TextDirection.ltr,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout(maxWidth: 34);
    final lines = painter.computeLineMetrics();
    // The pause between words is smaller than one full character cell.
    expect(lines[4].baseline - lines[2].baseline, lessThan(17));
    painter.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('truncation keeps the ellipsis full size at a word boundary', (
    tester,
  ) async {
    for (final height in [40.0, 50.0, 60.0, 70.0, 80.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 34,
              height: height,
              child: VerticalSpineTitle(
                '가 가 가 가 가 가 가 가 가 가',
                style: const DesignPalette(Mood.a).text(11, height: 1),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(VerticalSpineTitle),
          matching: find.byType(Text),
        ),
      );
      final spans = (text.textSpan! as TextSpan).children!
          .whereType<TextSpan>();
      final ellipsis = spans.singleWhere((span) => span.text == '⋮');
      expect(ellipsis.style!.fontSize, 11);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('vertical titles keep compact baselines without clipping', (
    tester,
  ) async {
    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Center(
              child: SizedBox(
                width: 34,
                height: 100,
                child: VerticalSpineTitle(
                  '가나다라마바사아자차카타파하',
                  style: const DesignPalette(Mood.a).text(11, height: 1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final glyphs = find.descendant(
        of: find.byType(VerticalSpineTitle),
        matching: find.byType(Text),
      );
      expect(glyphs, findsOneWidget);
      expect(
        tester.widget<Text>(glyphs).textSpan!.toPlainText(),
        contains('⋮'),
      );
      for (final element in glyphs.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width),
          ),
          reason: 'Glyph must retain its full scaled line at $scale',
        );
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
          textHeightBehavior: paragraph.textHeightBehavior,
          maxLines: paragraph.maxLines,
        )..layout(maxWidth: paragraph.size.width);
        final lines = painter.computeLineMetrics();
        expect(lines.length, greaterThan(1));
        for (var i = 1; i < lines.length; i++) {
          final pitch = lines[i].baseline - lines[i - 1].baseline;
          expect(pitch, closeTo(11 * scale, 1), reason: 'No added glyph gap');
        }
        painter.dispose();
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty-card actions stay separate and tappable with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.reset);
    for (final scale in [1.5, 2.0]) {
      for (final mood in Mood.values) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ReadingWorkspace(
              key: UniqueKey(),
              embedded: true,
              initialMood: mood,
              initialScreen: 'card-empty',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<ReadingWorkspaceState>(
          find.byType(ReadingWorkspace),
        );
        state.flipCard('card-front');
        await tester.pumpAndSettle();
        final action = find.text('첫 기록 남기기');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${mood.name} at $scale',
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('독서 상태'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'large text preserves shelf rows and navigation on a narrow phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.reset);
      for (final scale in [1.5, 2.0]) {
        for (final mood in Mood.values) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ReadingWorkspace(
                key: UniqueKey(),
                embedded: true,
                initialMood: mood,
                initialScreen: 'shelf',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('기본 서가'), findsOneWidget);
          expect(find.text('주제 서가'), findsOneWidget);
          for (var row = 0; row < 3; row++) {
            expect(
              tester.getSize(find.byKey(ValueKey('shelf-0-row-$row'))).height,
              greaterThan(0),
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${mood.name} at $scale',
          );
        }
      }
    },
  );
}
