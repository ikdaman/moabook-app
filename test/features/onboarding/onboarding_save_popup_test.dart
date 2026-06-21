import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/onboarding/widget/onboarding_save_popup.dart';

const _book = BookItem(
  title: 'UX/UI 디자인 완벽 가이드', author: '저자', cover: '', publisher: '출판',
  isbn: '123', itemId: 1, link: '', description: '', pubDate: '2024', totalPage: 100,
);

void main() {
  testWidgets('SAVE 누르면 saved=true + 이유 반환', (tester) async {
    OnboardingSaveResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return Center(
            child: ElevatedButton(
              onPressed: () async =>
                  result = await showOnboardingSavePopup(ctx, _book),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('책 추가'), findsOneWidget);
    expect(find.text('UX/UI 디자인 완벽 가이드'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '읽고 싶어요');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.saved, isTrue);
    expect(result!.reason, '읽고 싶어요');
  });
}
