import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/onboarding/widget/onboarding_save_popup.dart';

const _book = BookItem(
  title: 'UX/UI 디자인 완벽 가이드',
  author: '저자',
  cover: '',
  publisher: '출판',
  isbn: '123',
  itemId: 1,
  link: '',
  description: '',
  pubDate: '2024',
  totalPage: 100,
);

void main() {
  testWidgets('책 선택 완료 시 선택 결과와 이유 반환', (tester) async {
    OnboardingSaveResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      result = await showOnboardingSavePopup(ctx, _book),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('첫 마음 남기기'), findsOneWidget);
    expect(find.text('UX/UI 디자인 완벽 가이드'), findsWidgets);
    await tester.enterText(find.byType(TextField), '읽고 싶어요');
    await tester.tap(find.text('이 책으로 시작하기'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.saved, isTrue);
    expect(result!.reason, '읽고 싶어요');
  });
  testWidgets(
    'optional reason respects 400 grapheme characters without splitting emoji',
    (tester) async {
      OnboardingSaveResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showOnboardingSavePopup(context, _book),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        List.filled(401, '🙂').join(),
      );
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .characters
            .length,
        400,
      );
      await tester.tap(find.text('이 책으로 시작하기'));
      await tester.pumpAndSettle();
      expect(result!.reason!.characters.length, 400);
    },
  );
}
