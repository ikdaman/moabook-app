import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/onboarding/widget/pixel_fireworks.dart';

void main() {
  testWidgets('폭죽이 예외 없이 여러 프레임 렌더', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 268, height: 150, child: PixelFireworks()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    expect(find.byType(PixelFireworks), findsOneWidget);
  });
}
