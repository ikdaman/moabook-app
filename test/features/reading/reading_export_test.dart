import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:moabook/features/reading/export/reading_export_screen.dart';
import 'package:moabook/features/reading/export/reading_image_renderer.dart';
import 'package:moabook_reading/moabook_reading.dart';

ReadingImageExport request(int count) => ReadingImageExport(
  title: '나의 서가',
  books: [
    for (var i = 1; i <= count; i++)
      ReadingBook(
        '$i',
        '긴 제목을 가진 책 $i',
        '작가',
        '출판사',
        i == 1 ? '다시 읽고 싶은 이유' : '',
        '',
      ),
  ],
);
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class PreviewRenderer extends ReadingImageRenderer {
  @override
  Future<Uint8List> render(ReadingImageExport request, int page) async =>
      tinyPng;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('large library is paged without losing or duplicating books', () {
    final value = request(20);
    expect(value.pageCount, 3);
    expect(
      [
        for (var i = 0; i < value.pageCount; i++) ...value.page(i),
      ].map((b) => b.id),
      [for (var i = 1; i <= 20; i++) '$i'],
    );
    expect(value.page(2).length, 2);
    expect(() => value.page(3), throwsRangeError);
  });
  test(
    'missing and failed cover downloads still produce a full-resolution PNG',
    () async {
      final renderer = ReadingImageRenderer(
        loadCover: (_) async => throw StateError('offline'),
      );
      final bytes = await renderer.render(request(2), 0);
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1080);
      expect(frame.image.height, 1720);
      frame.image.dispose();
      codec.dispose();
    },
  );
  testWidgets('failed second save resumes only remaining images', (
    tester,
  ) async {
    var failSecond = true;
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingExportScreen(
          request: request(10),
          renderer: PreviewRenderer(),
          saveImage: (_, name) async {
            calls.add(name);
            if (name.endsWith('-2') && failSecond) throw StateError('no space');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('사진에 저장'));
    await tester.pumpAndSettle();
    expect(find.text('1장 저장됨 · 다시 시도하면 남은 이미지만 저장해요.'), findsOneWidget);
    failSecond = false;
    await tester.tap(find.text('남은 이미지 저장'));
    await tester.pumpAndSettle();
    expect(calls.length, 3);
    expect(calls.where((name) => name.endsWith('-1')).length, 1);
    expect(find.text('사진에 2장 저장했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'denied gallery permission is explained without claiming success',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingExportScreen(
            request: request(1),
            renderer: PreviewRenderer(),
            saveImage: (_, _) async {
              throw GalException(
                type: GalExceptionType.accessDenied,
                platformException: PlatformException(code: 'ACCESS_DENIED'),
                stackTrace: StackTrace.current,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진에 저장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('사진 저장 권한이 필요해요.'), findsOneWidget);
      expect(find.text('저장 완료'), findsNothing);
    },
  );
}
