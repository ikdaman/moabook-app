import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/cover_ocr/screen/cover_crop_screen.dart';

// 1x1 투명 PNG (crop_your_image가 디코드 가능한 유효 이미지)
final _pngBytes = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
));

void main() {
  testWidgets('CoverCropScreen — 렌더 + 확인 버튼 노출', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CoverCropScreen(imageBytes: _pngBytes)),
    );
    await tester.pump();

    expect(find.text('영역 선택'), findsOneWidget);
    expect(find.byKey(const Key('crop_confirm_button')), findsOneWidget);
  });
}
