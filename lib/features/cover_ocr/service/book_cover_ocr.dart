// book_cover_ocr.dart
//
// 책 표지 이미지에서 ML Kit OCR로 텍스트를 뽑고,
// "제목일 확률이 높은 후보"를 점수 순으로 골라내는 로직.
//
// pubspec.yaml:
//   google_mlkit_text_recognition: ^0.13.0   // (pub.dev에서 최신 버전 확인)
//
// 흐름: 표지 촬영 → recognizeBookCover(imagePath) → List<TitleCandidate>
//      → 1~2위 후보로 알라딘 검색 → 결과 카드 보여주고 사용자가 선택

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 제목 후보 한 줄. score가 높을수록 제목일 가능성이 큼.
class TitleCandidate {
  final String text;
  final double score;
  final double height; // 글자 높이(px) — 디버깅용
  final Rect box;

  TitleCandidate({
    required this.text,
    required this.score,
    required this.height,
    required this.box,
  });

  @override
  String toString() =>
      '"$text"  (score: ${score.toStringAsFixed(1)}, h: ${height.toStringAsFixed(0)})';
}

/// 표지 이미지 경로를 받아 제목 후보들을 점수 순으로 반환.
///
/// iOS: 네이티브 Vision(Share Extension 과 동일한 CoverOcr.swift)이 ML Kit보다
/// 인식률이 좋아 MethodChannel 로 위임. 점수화 로직은 양쪽 동일.
/// Android: ML Kit (한국어 스크립트 인식기는 한글 + 라틴 문자를 같이 읽어줌).
Future<List<TitleCandidate>> recognizeBookCover(String imagePath) async {
  if (Platform.isIOS) {
    return _recognizeWithVision(imagePath);
  }
  return _recognizeWithMlKit(imagePath);
}

const _visionChannel = MethodChannel('moabook/cover_ocr');

Future<List<TitleCandidate>> _recognizeWithVision(String imagePath) async {
  final raw = await _visionChannel
      .invokeListMethod<dynamic>('recognize', {'path': imagePath});
  if (raw == null) return [];
  return [
    for (final item in raw.cast<Map<dynamic, dynamic>>())
      TitleCandidate(
        text: item['text'] as String,
        score: (item['score'] as num).toDouble(),
        height: 0, // Vision 경로는 정규화 좌표 — 디버깅용 픽셀 값 없음
        box: Rect.zero,
      ),
  ];
}

Future<List<TitleCandidate>> _recognizeWithMlKit(String imagePath) async {
  final recognizer =
      TextRecognizer(script: TextRecognitionScript.korean);

  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await recognizer.processImage(inputImage);

    // 1) 전체 라인 수집 + 표지에서 가장 큰 글자 높이 파악(상대 비교용)
    final List<TextLine> lines = [];
    for (final block in result.blocks) {
      lines.addAll(block.lines);
    }
    if (lines.isEmpty) return [];

    double maxHeight = 0;
    for (final line in lines) {
      final h = line.boundingBox.height.toDouble();
      if (h > maxHeight) maxHeight = h;
    }

    // 표지에서 텍스트가 차지하는 세로 범위(위치 점수 정규화용)
    double minY = double.infinity, maxY = 0;
    for (final line in lines) {
      minY = line.boundingBox.top < minY ? line.boundingBox.top.toDouble() : minY;
      maxY = line.boundingBox.bottom > maxY ? line.boundingBox.bottom.toDouble() : maxY;
    }
    final span = (maxY - minY).clamp(1, double.infinity);

    // 2) 각 라인을 점수화
    final candidates = <TitleCandidate>[];
    for (final line in lines) {
      final text = line.text.trim();
      if (isOcrNoiseLine(text)) continue;

      final box = line.boundingBox;
      final h = box.height.toDouble();

      // (a) 글자 크기 점수: 가장 큰 글자 대비 비율 (0~60점) — 제일 강한 신호
      final sizeScore = (h / maxHeight) * 60;

      // (b) 위치 점수: 위쪽일수록 가산 (0~25점). 제목은 보통 상단~중앙.
      final relY = (box.center.dy - minY) / span; // 0(맨위)~1(맨아래)
      final positionScore = (1 - relY) * 25;

      // (c) 길이 점수: 너무 짧거나(1~2자) 너무 긴 문장은 제목이 아닐 확률↑ (0~15점)
      final len = text.replaceAll(RegExp(r'\s'), '').length;
      double lengthScore = 0;
      if (len >= 2 && len <= 25) {
        lengthScore = 15;
      } else if (len > 25 && len <= 40) {
        lengthScore = 7;
      }

      candidates.add(TitleCandidate(
        text: text,
        score: sizeScore + positionScore + lengthScore,
        height: h,
        box: box,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 3) 여러 줄 제목 결합 후보를 최우선으로 삽입.
    //    (노이즈 라인은 결합 재료에서도 제외)
    final combined = combineAdjacentTitleLines([
      for (final line in lines)
        if (!isOcrNoiseLine(line.text.trim()))
          OcrLineBox(
            text: line.text.trim(),
            top: line.boundingBox.top.toDouble(),
            height: line.boundingBox.height.toDouble(),
            left: line.boundingBox.left.toDouble(),
            right: line.boundingBox.right.toDouble(),
          ),
    ]);
    if (combined != null &&
        candidates.isNotEmpty &&
        !candidates.any((c) => c.text == combined)) {
      candidates.insert(
        0,
        TitleCandidate(
          text: combined,
          score: candidates.first.score + 1,
          height: 0,
          box: Rect.zero,
        ),
      );
    }
    return candidates;
  } finally {
    await recognizer.close(); // 메모리 누수 방지 — 꼭 닫기
  }
}

/// OCR 라인 박스. 좌표 단위는 무관 — 상대 비교만 한다 (위에서 아래로 증가).
class OcrLineBox {
  final String text;
  final double top;
  final double height;
  final double left;
  final double right;

  const OcrLineBox({
    required this.text,
    required this.top,
    required this.height,
    required this.left,
    required this.right,
  });

  double get bottom => top + height;
}

/// 여러 줄 제목 결합: 가장 큰 라인(주 제목)과 세로로 붙어 있고 가로 범위가
/// 겹치며 크기가 비슷한(35%↑) 라인을 위·아래 1줄씩 이어붙인다.
/// 예) "질문으로 시작하는" + "세계사 수업" → "질문으로 시작하는 세계사 수업"
/// 결합할 게 없으면 null.
String? combineAdjacentTitleLines(List<OcrLineBox> lines) {
  if (lines.length < 2) return null;
  final main = lines.reduce((a, b) => a.height >= b.height ? a : b);

  bool adjacent(OcrLineBox o) {
    if (identical(o, main)) return false;
    if (o.height < main.height * 0.35) return false;
    final gap =
        o.top >= main.top ? o.top - main.bottom : main.top - o.bottom;
    if (gap > main.height) return false;
    final overlap =
        math.min(o.right, main.right) - math.max(o.left, main.left);
    return overlap > 0;
  }

  OcrLineBox? above;
  OcrLineBox? below;
  for (final o in lines) {
    if (!adjacent(o)) continue;
    if (o.bottom <= main.top + main.height * 0.5) {
      if (above == null || o.top > above.top) above = o;
    } else if (o.top >= main.top + main.height * 0.5) {
      if (below == null || o.top < below.top) below = o;
    }
  }
  if (above == null && below == null) return null;
  return [
    if (above != null) above.text.trim(),
    main.text.trim(),
    if (below != null) below.text.trim(),
  ].join(' ');
}

/// 제목이 아닐 게 거의 확실한 라인을 걸러냄.
/// (공개 함수 — 테스트와 Swift 포팅본(CoverOcr.swift isNoise) 동기화 대상.)
bool isOcrNoiseLine(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;

  // 가격: "18,000원", "₩18000", "값 15000"
  if (RegExp(r'(₩|값)?\s*\d{1,3}([,\.]\d{3})+\s*원?').hasMatch(t)) return true;

  // ISBN / 바코드 숫자열 (긴 숫자 덩어리)
  if (RegExp(r'\d{9,}').hasMatch(t)) return true;
  if (RegExp(r'ISBN', caseSensitive: false).hasMatch(t)) return true;

  // 숫자/기호만 있는 라인 (스크린샷 상태바 시계 "1:53", "154 3•" 포함)
  if (RegExp(r'^[\d\s\-\.\|/:•%<>*]+$').hasMatch(t)) return true;

  // ── 스크린샷/SNS 잡동사니 (갤러리 공유 이미지 실측 기반) ──
  // 단독 토큰 라틴+숫자 혼합: 상태바 아이콘 오독 "087a05", "G1"
  if (RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$').hasMatch(t)) return true;
  // 유저명/도메인 토큰: "travel_0photo", "elly_camping"
  if (RegExp(r'^[A-Za-z0-9._]*[._][A-Za-z0-9._]*$').hasMatch(t)) return true;
  // 경과시간/카운트: "7분", "1천", "facelessowner 1일", "22시간 전"
  if (RegExp(r'^(\S+\s+)?\d+\s*(분|시간|일|주|개월|년|천|만|억)(\s*전)?$')
      .hasMatch(t)) {
    return true;
  }

  // 표지 상투어 (필요에 맞게 추가/삭제)
  const cliches = [
    '베스트셀러', '개정판', '초판', '스테디셀러', '추천', '화제의',
    '전국서점', '값', '정가', '바코드', '세트',
  ];
  for (final c in cliches) {
    if (t == c) return true;
  }

  return false;
}
