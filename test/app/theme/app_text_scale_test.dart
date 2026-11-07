import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/app/theme/app_theme.dart';

void main() {
  testWidgets('app typography stays fixed across system font sizes', (
    tester,
  ) async {
    Size? baseline;
    for (final systemScale in [0.8, 1.0, 1.5, 2.0]) {
      final systemData = MediaQueryData(
        textScaler: TextScaler.linear(systemScale),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
        viewInsets: const EdgeInsets.only(bottom: 200),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: systemData,
          child: MaterialApp(
            builder: (context, child) {
              expect(
                MediaQuery.textScalerOf(context).scale(20),
                20 * systemScale,
              );
              return fixedAppTextScale(context, child);
            },
            home: Builder(
              builder: (context) {
                final data = MediaQuery.of(context);
                expect(data.padding, systemData.padding);
                expect(data.viewInsets, systemData.viewInsets);
                expect(data.textScaler.scale(20), 20);
                return const Scaffold(
                  body: Text('모아북 글자 크기', style: TextStyle(fontSize: 20)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.text('모아북 글자 크기'));
      baseline ??= size;
      expect(size, baseline, reason: 'System scale $systemScale');
      expect(tester.takeException(), isNull);
    }
  });
}
