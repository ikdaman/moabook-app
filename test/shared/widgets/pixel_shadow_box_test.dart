import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/shared/widgets/pixel_shadow_box.dart';

void main() {
  testWidgets('PixelShadowBox renders child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PixelShadowBox(child: Text('hello'))),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('PixelShadowButton calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PixelShadowButton(
            onTap: () => tapped = true,
            child: const Text('btn'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('btn'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
