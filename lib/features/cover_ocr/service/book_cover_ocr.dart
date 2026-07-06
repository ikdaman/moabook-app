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

import 'dart:ui';
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
/// 한국어 스크립트 인식기는 한글 + 라틴 문자를 같이 읽어줌.
Future<List<TitleCandidate>> recognizeBookCover(String imagePath) async {
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
      if (_isNoise(text)) continue;

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
    return candidates;
  } finally {
    await recognizer.close(); // 메모리 누수 방지 — 꼭 닫기
  }
}

/// 제목이 아닐 게 거의 확실한 라인을 걸러냄.
bool _isNoise(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;

  // 가격: "18,000원", "₩18000", "값 15000"
  if (RegExp(r'(₩|값)?\s*\d{1,3}([,\.]\d{3})+\s*원?').hasMatch(t)) return true;

  // ISBN / 바코드 숫자열 (긴 숫자 덩어리)
  if (RegExp(r'\d{9,}').hasMatch(t)) return true;
  if (RegExp(r'ISBN', caseSensitive: false).hasMatch(t)) return true;

  // 숫자/기호만 있는 라인
  if (RegExp(r'^[\d\s\-\.\|/]+$').hasMatch(t)) return true;

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
