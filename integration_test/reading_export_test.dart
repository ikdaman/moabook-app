import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moabook/features/reading/export/reading_export_screen.dart';
import 'package:moabook_reading/moabook_reading.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('saves the rendered collection to the system photo library', (tester) async {
    // This test writes one generated image, never account or server data.
    expect(await Gal.hasAccess(), isTrue, reason: 'Grant photo-add access to this test device first');
    await tester.pumpWidget(MaterialApp(home: ReadingExportScreen(request: ReadingImageExport(
      title: '함께 간직할 책', books: const [
        ReadingBook('test-1', '책과 함께 보낸 시간', '모아북', '', '천천히 오래 읽고 싶어서', ''),
        ReadingBook('test-2', '다음 계절에 만날 이야기', '모아북', '', '', ''),
      ],
    ))));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('사진에 저장'));
    for (var i = 0; i < 120 && find.text('저장 완료').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('사진에 1장 저장했어요.'), findsOneWidget);
    expect(find.text('저장 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
