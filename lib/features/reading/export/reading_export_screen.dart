import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import 'reading_image_renderer.dart';

class ReadingExportScreen extends StatefulWidget {
  const ReadingExportScreen({
    super.key,
    required this.request,
    this.renderer,
    this.saveImage,
  });
  final ReadingImageExport request;
  final ReadingImageRenderer? renderer;
  final Future<void> Function(Uint8List bytes, String name)? saveImage;
  @override
  State<ReadingExportScreen> createState() => _ReadingExportScreenState();
}

class _ReadingExportScreenState extends State<ReadingExportScreen> {
  static const palette = DesignPalette(Mood.a);
  late final renderer = widget.renderer ?? ReadingImageRenderer();
  late Future<Uint8List> preview = renderer.render(widget.request, 0);
  final saved = <int>{};
  final batchName = 'moabook-${DateTime.now().microsecondsSinceEpoch}';
  int page = 0;
  bool saving = false;
  String? message;

  Future<void> save() async {
    if (saving || widget.request.books.isEmpty) return;
    setState(() {
      saving = true;
      message = null;
    });
    try {
      for (var i = 0; i < widget.request.pageCount; i++) {
        if (saved.contains(i)) continue;
        final bytes = i == page
            ? await preview
            : await renderer.render(widget.request, i);
        if (!mounted) return;
        if (widget.saveImage != null) {
          await widget.saveImage!(bytes, '$batchName-${i + 1}');
        } else {
          await Gal.putImageBytes(bytes, name: '$batchName-${i + 1}');
        }
        if (!mounted) return;
        setState(() => saved.add(i));
      }
      if (mounted) setState(() => message = '사진에 ${saved.length}장 저장했어요.');
    } on GalException catch (error) {
      if (mounted) {
        setState(
          () => message = switch (error.type) {
            GalExceptionType.accessDenied =>
              '사진 저장 권한이 필요해요. 설정에서 권한을 허용한 뒤 다시 시도해주세요.',
            GalExceptionType.notEnoughSpace => '기기 저장 공간이 부족해요.',
            _ => '사진을 저장하지 못했어요. 다시 시도해주세요.',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => message = '이미지를 저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  PreferredSizeWidget appBar() => AppBar(
    title: Text('이미지 저장', style: palette.text(20, weight: 600)),
    backgroundColor: palette.background,
    foregroundColor: palette.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    automaticallyImplyLeading: !saving,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Divider(height: 1, thickness: 1, color: palette.ink),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      Theme(data: palette.theme, child: buildContent(context));

  Widget buildContent(BuildContext context) {
    if (widget.request.books.isEmpty) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: appBar(),
        body: Center(
          child: Text(
            '저장할 책이 없어요.',
            style: palette.text(15, color: palette.muted),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: appBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              children: [
                Text(
                  '${widget.request.books.length}권을 ${widget.request.pageCount}장의 이미지로 저장합니다.',
                  style: palette.text(13, color: palette.muted),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<Uint8List>(
                    future: preview,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton(
                            onPressed: saving
                                ? null
                                : () => setState(
                                    () => preview = renderer.render(
                                      widget.request,
                                      page,
                                    ),
                                  ),
                            child: Text(
                              '미리보기 다시 만들기',
                              style: palette.text(14, weight: 600),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: palette.ink),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.card,
                          border: Border.all(color: palette.line),
                        ),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '이전 이미지',
                      onPressed: saving || page == 0
                          ? null
                          : () => setState(() {
                              --page;
                              preview = renderer.render(widget.request, page);
                            }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${page + 1} / ${widget.request.pageCount}',
                      style: palette.text(12, mono: true),
                    ),
                    IconButton(
                      tooltip: '다음 이미지',
                      onPressed: saving || page + 1 == widget.request.pageCount
                          ? null
                          : () => setState(() {
                              ++page;
                              preview = renderer.render(widget.request, page);
                            }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      message!,
                      style: palette.text(13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (saved.isNotEmpty && saved.length < widget.request.pageCount)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${saved.length}장 저장됨 · 다시 시도하면 남은 이미지만 저장해요.',
                      style: palette.text(12, color: palette.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.button,
                      foregroundColor: palette.onButton,
                      disabledBackgroundColor: palette.line,
                      disabledForegroundColor: palette.ink,
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: const RoundedRectangleBorder(),
                      textStyle: palette.text(
                        15,
                        weight: 600,
                        color: palette.onButton,
                      ),
                    ),
                    onPressed:
                        saving || saved.length == widget.request.pageCount
                        ? null
                        : save,
                    child: Text(
                      saving
                          ? '저장 중 ${saved.length}/${widget.request.pageCount}'
                          : saved.length == widget.request.pageCount
                          ? '저장 완료'
                          : saved.isEmpty
                          ? '사진에 저장'
                          : '남은 이미지 저장',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
