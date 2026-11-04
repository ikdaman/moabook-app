import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moabook_reading/moabook_reading.dart';

typedef ReadingCoverLoader = Future<ui.Image?> Function(String? url);

class ReadingImageRenderer {
  ReadingImageRenderer({ReadingCoverLoader? loadCover})
    : loadCover = loadCover ?? loadPublicCover;
  final ReadingCoverLoader loadCover;
  static const width = 1080, height = 1720;
  static const ink = Color(0xff232c28), paper = Color(0xfff6f4ef);

  Future<Uint8List> render(ReadingImageExport request, int page) async {
    final books = request.page(page);
    final images = await Future.wait(
      books.map((b) async {
        try {
          return await loadCover(b.coverUrl);
        } catch (_) {
          return null;
        }
      }),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(paper, BlendMode.src);
    void text(
      String value,
      Offset at,
      double size,
      double maxWidth, {
      int lines = 1,
      Color color = ink,
      FontWeight weight = FontWeight.normal,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'PlexKR',
            fontSize: size,
            color: color,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, at);
      painter.dispose();
    }

    text('MOABOOK', const Offset(54, 40), 25, 972, weight: FontWeight.w600);
    text(
      request.title,
      const Offset(54, 88),
      44,
      972,
      lines: 2,
      weight: FontWeight.w600,
    );
    canvas.drawLine(
      const Offset(54, 212),
      const Offset(1026, 212),
      Paint()
        ..color = ink
        ..strokeWidth = 2,
    );
    try {
      for (var i = 0; i < books.length; i++) {
        final book = books[i];
        final left = 54.0 + (i % 3) * 330;
        final top = 246.0 + (i ~/ 3) * 454;
        final rect = Rect.fromLTWH(left + 42, top, 228, 300);
        canvas.drawRect(rect, Paint()..color = const Color(0xffdedbd2));
        if (images[i] != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: images[i]!,
            fit: BoxFit.contain,
          );
        } else {
          text(book.title, Offset(rect.left + 16, top + 90), 24, 196, lines: 4);
        }
        if (book.reason.isNotEmpty) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, top + 242, 228, 58),
            Paint()..color = const Color(0xffdf6c38),
          );
          text(
            book.reason,
            Offset(rect.left + 10, top + 246),
            17,
            208,
            lines: 2,
          );
        }
        text(
          book.title,
          Offset(left, top + 314),
          24,
          312,
          lines: 2,
          weight: FontWeight.w600,
        );
        text(
          book.author,
          Offset(left, top + 385),
          18,
          312,
          lines: 2,
          color: const Color(0xff626d66),
        );
      }
      text(
        '${request.books.length}권 · ${page + 1} / ${request.pageCount}',
        const Offset(54, 1645),
        22,
        972,
      );
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(width, height);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('PNG encoding failed');
          return bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      for (final image in images) {
        image?.dispose();
      }
    }
  }

  static Future<ui.Image?> loadPublicCover(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
    // Covers are public. Never attach the account's authorization header.
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ),
    );
    try {
      final response = await dio.get<List<int>>(
        uri.toString(),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.length > 8 * 1024 * 1024) return null;
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(data),
        targetWidth: 228,
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      dio.close(force: true);
    }
  }
}
