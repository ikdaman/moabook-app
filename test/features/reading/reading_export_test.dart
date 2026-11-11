import 'dart:convert';
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
  int calls = 0;
  @override
  Future<Uint8List> render(ReadingImageExport request, int page) async {
    calls++;
    return tinyPng;
  }
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
    'basic shelf uses captured spine pages without reflowing into cover grids',
    () async {
      final books = request(20).books;
      final value = ReadingImageExport.shelf(
        title: '나의 서가',
        pages: [
          ReadingShelfImage(books: books.take(15), png: tinyPng),
          ReadingShelfImage(books: books.skip(15), png: tinyPng),
        ],
      );
      expect(value.pageCount, 2);
      expect(value.page(0).length, 15);
      expect(value.page(1).length, 5);
      expect(value.books.map((book) => book.id), books.map((book) => book.id));
      final renderer = ReadingImageRenderer(
        loadCover: (_) async => throw StateError('Spines do not load covers'),
      );
      expect(await renderer.render(value, 1), same(tinyPng));
    },
  );

  test(
    'collection export uses its captured screen image without reflow or downloads',
    () async {
      final value = ReadingImageExport.collection(
        title: '화면의 컬렉션 이름',
        slots: [request(1).books.first, ...List<ReadingBook?>.filled(8, null)],
        png: tinyPng,
      );
      final renderer = ReadingImageRenderer(
        loadCover: (_) async =>
            throw StateError('Captured covers must not download again'),
      );
      expect(await renderer.render(value, 0), same(tinyPng));
      expect(value.title, '화면의 컬렉션 이름');
    },
  );
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
  test(
    'cover exports always retain the full nine-slot canvas, including the last page',
    () async {
      var covers = 0;
      final renderer = ReadingImageRenderer(
        loadCover: (url) async {
          covers++;
          final data = await rootBundle.load(
            'assets/design_preview/covers/human.jpg',
          );
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 228,
          );
          try {
            return (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        },
      );
      for (final count in [1, 4, 9, 10]) {
        final value = ReadingImageExport(
          title: '여러 줄에 걸쳐 표시되는 아주 긴 컬렉션 제목을 가진 나의 책장',
          books: [
            for (var i = 0; i < count; i++)
              ReadingBook(
                '$i',
                '길고 긴 책 제목과 부제목이 여러 줄을 넘으면 말줄임으로 표시해요',
                '긴 작가 이름, 공동 저자, 번역가 이름',
                '',
                '여러 줄에 걸쳐 표시할 읽고 싶은 이유와 기억',
                '',
                coverUrl: 'local-test-cover',
              ),
          ],
        );
        final last = value.pageCount - 1;
        final bytes = await renderer.render(value, last);
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final image = (await codec.getNextFrame()).image;
          expect(image.width, 1080);
          expect(image.height, 1720);
          image.dispose();
        } finally {
          codec.dispose();
        }
      }
      expect(covers, 15);
    },
  );

  test(
    'a single book in slot nine leaves the first eight slots blank',
    () async {
      final value = ReadingImageExport.collection(
        title: '모음',
        slots: [...List<ReadingBook?>.filled(8, null), request(1).books.single],
      );
      final bytes = await ReadingImageRenderer(
        loadCover: (_) async => null,
      ).render(value, 0);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width, 1080);
        expect(image.height, 1720);
        expect(value.books.length, 1);
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        List<int> pixel(int x, int y) => pixels!.buffer
            .asUint8List(pixels.offsetInBytes + (y * image.width + x) * 4, 4)
            .toList();
        expect(pixel(100, 250), [246, 244, 239, 255]);
        expect(pixel(760, 1170), [222, 219, 210, 255]);
      } finally {
        image.dispose();
        codec.dispose();
      }
    },
  );

  test('collection image contains only covers and border lines', () async {
    final renderer = ReadingImageRenderer(
      loadCover: (_) async {
        final data = await rootBundle.load(
          'assets/design_preview/covers/human.jpg',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 228,
        );
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      },
    );
    ReadingImageExport collection(String text) => ReadingImageExport.collection(
      title: text,
      slots: [
        ReadingBook('1', text, text, text, text, '', coverUrl: 'cover'),
        ...List<ReadingBook?>.filled(8, null),
      ],
    );
    final bytes = await renderer.render(collection('제목, 저자, 설명을 숨겨요'), 0);
    expect(bytes, await renderer.render(collection('전혀 다른 내용'), 0));
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      List<int> pixel(int x, int y) => pixels.buffer
          .asUint8List(pixels.offsetInBytes + (y * image.width + x) * 4, 4)
          .toList();
      expect(pixel(54, 100), [35, 44, 40, 255]);
      expect(pixel(100, 600), [246, 244, 239, 255]);
      expect(pixel(100, 1600), [246, 244, 239, 255]);
      expect(pixel(200, 350), isNot([246, 244, 239, 255]));
    } finally {
      image.dispose();
      codec.dispose();
    }
  });

  testWidgets(
    'empty export shows an empty state without rendering or offering save',
    (tester) async {
      final renderer = PreviewRenderer();
      await tester.pumpWidget(
        MaterialApp(
          home: ReadingExportScreen(request: request(0), renderer: renderer),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('저장할 책이 없어요.'), findsOneWidget);
      expect(find.text('사진에 저장'), findsNothing);
      expect(find.text('저장 완료'), findsNothing);
      expect(renderer.calls, 0);
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
