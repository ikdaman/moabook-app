// test/features/onboarding/typing_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/onboarding/widget/typing_text.dart';

void main() {
  testWidgets('한 글자씩 타이핑되고 완료 콜백 호출', (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypingText(
          phrases: const ['모아북'],
          charInterval: const Duration(milliseconds: 10),
          holdDuration: const Duration(milliseconds: 10),
          onComplete: () => done = true,
        ),
      ),
    ));
    // 초기엔 아직 전체 안 나옴
    await tester.pump(const Duration(milliseconds: 15)); // 1글자
    expect(find.textContaining('모'), findsOneWidget);
    expect(find.textContaining('모아북'), findsNothing);
    // 충분히 진행하면 전체 + onComplete
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('모아북'), findsOneWidget);
    expect(done, isTrue);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
  });

  testWidgets('dispose 후 setState 예외 없음', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypingText(
          phrases: const ['안녕하세요반갑습니다'],
          charInterval: const Duration(milliseconds: 30),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
