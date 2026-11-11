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
  static const width = 1080, rowHeight = 454;
  static int heightForBooks(int count) {
    if (count < 1 || count > ReadingImageExport.pageSize) {
      throw RangeError.range(count, 1, ReadingImageExport.pageSize, 'count');
    }
    return 1720;
  }

  static const ink = Color(0xff232c28), paper = Color(0xfff6f4ef);

  Future<Uint8List> render(ReadingImageExport request, int page) async {
    final pageBooks = request.page(page);
    if (request.collectionPng != null) return request.collectionPng!;
    final books = request.collectionSlots ?? pageBooks;
    if (request.shelfPages.isNotEmpty) return request.shelfPages[page].png;
    final height = heightForBooks(books.length);
    final images = await Future.wait(
      books.map((b) async {
        try {
          return b == null ? null : await loadCover(b.coverUrl);
        } catch (_) {
          return null;
        }
      }),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(paper, BlendMode.src);
    final border = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(54, 54, 972, height - 108.0), border);
    try {
      for (var i = 0; i < books.length; i++) {
        final book = books[i];
        if (book == null) continue;
        final left = 54.0 + (i % 3) * 330;
        final top = 256.0 + (i ~/ 3) * rowHeight;
        final rect = Rect.fromLTWH(left + 42, top, 228, 300);
        canvas.drawRect(rect, Paint()..color = const Color(0xffdedbd2));
        if (images[i] != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: images[i]!,
            fit: BoxFit.contain,
          );
        }
        canvas.drawRect(rect, border);
      }
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
