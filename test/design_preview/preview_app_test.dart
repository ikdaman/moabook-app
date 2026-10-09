import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/design_preview/design_system.dart';
import 'package:moabook/design_preview/preview_app.dart';
import 'package:moabook/design_preview/sample_data.dart';

void main() {
  testWidgets('all design screens fit iPhone and narrow widths in both moods', (
    tester,
  ) async {
    for (final size in [const Size(402, 874), const Size(320, 740)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      for (final mood in Mood.values) {
        for (final screen in previewScreens.keys) {
          await tester.pumpWidget(
            DesignPreviewApp(
              key: UniqueKey(),
              initialMood: mood,
              initialScreen: screen,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${mood.name}/$screen at $size',
          );
        }
      }
    }
    addTearDown(tester.view.reset);
  });

  testWidgets(
    'collection title opens index and choosing a collection returns to shelf',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const DesignPreviewApp(initialScreen: 'collection'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-picker')));
      await tester.pumpAndSettle();
      expect(find.text('나의 컬렉션'), findsOneWidget);
      await tester.tap(find.text('새드엔딩'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-picker')), findsOneWidget);
      expect(find.text('새드엔딩'), findsOneWidget);
    },
  );

  testWidgets('collection editing exposes the save action', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const DesignPreviewApp(initialScreen: 'collection-edit'),
    );
    await tester.pumpAndSettle();
    final save = find.text('3권으로 컬렉션 저장');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collection-picker')), findsOneWidget);
  });

  testWidgets('saving retains the three reading state choices', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DesignPreviewApp(initialScreen: 'save-wish'));
    await tester.pumpAndSettle();
    expect(find.text('읽고 싶은 이유'), findsOneWidget);
    await tester.tap(find.text('읽고 있는 책'));
    await tester.pumpAndSettle();
    expect(find.text('읽기 시작한 날'), findsOneWidget);
    expect(find.text('다 읽은 날'), findsNothing);
    await tester.tap(find.text('읽은 책'));
    await tester.pumpAndSettle();
    expect(find.text('다 읽은 날'), findsOneWidget);
  });
}
