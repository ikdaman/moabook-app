// 표지 OCR 실험 화면 (실험용 — 검증 후 바코드 폴백 플로우에 통합 예정)
//
// 흐름: 촬영/갤러리 → recognizeBookCover() → 제목 후보(점수순) 표시
//      → 상위 후보로 알라딘 검색 → 중복 제거 → 결과 카드 리스트

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../book_search/provider/book_search_provider.dart';
import '../service/book_cover_ocr.dart';
import '../service/cover_ocr_search.dart';
import 'cover_crop_screen.dart';

class CoverOcrLabScreen extends ConsumerStatefulWidget {
  const CoverOcrLabScreen({super.key});

  @override
  ConsumerState<CoverOcrLabScreen> createState() => _CoverOcrLabScreenState();
}

class _CoverOcrLabScreenState extends ConsumerState<CoverOcrLabScreen> {
  final _picker = ImagePicker();

  String? _imagePath;
  // 크롭 소스로 쓸 "원본" 이미지 bytes. 촬영/갤러리로 고른 원본으로,
  // 크롭을 여러 번 해도 항상 원본에서 다시 영역을 고르도록 유지한다.
  // (크롭본이 아니라 원본을 잡아야 사용자가 원하는 영역을 다시 선택 가능)
  Uint8List? _originalBytes;
  // 크롭 결과 미리보기용 bytes. 크롭 임시 파일은 OCR 후 삭제되므로
  // 미리보기는 파일이 아니라 이 bytes로 표시한다(삭제된 경로 참조 방지).
  Uint8List? _previewBytes;
  List<TitleCandidate> _candidates = [];
  List<BookItem> _results = [];
  bool _running = false;
  String? _error;
  Duration? _ocrElapsed;
  Duration? _searchElapsed;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    // 새 원본 선택 — 크롭 소스를 이 원본으로 교체(직전 크롭본 폐기).
    try {
      _originalBytes = await File(file.path).readAsBytes();
    } catch (_) {
      _originalBytes = null;
    }
    await _runOcrPipeline(file.path);
  }

  /// 주어진 이미지 경로로 OCR + 알라딘 검색을 돌리고 화면 상태를 갱신한다.
  /// 촬영/갤러리 픽과 크롭본(임시파일)이 공유한다.
  ///
  /// [previewBytes]가 주어지면(크롭본) 미리보기/재크롭을 파일 대신 이 bytes로
  /// 표시한다. 촬영/갤러리 픽은 null(파일 경로로 미리보기).
  Future<void> _runOcrPipeline(String path, {Uint8List? previewBytes}) async {
    setState(() {
      _imagePath = path;
      _previewBytes = previewBytes;
      _candidates = [];
      _results = [];
      _error = null;
      _ocrElapsed = null;
      _searchElapsed = null;
      _running = true;
    });

    try {
      final ocrWatch = Stopwatch()..start();
      final candidates = await recognizeBookCover(path);
      ocrWatch.stop();

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _ocrElapsed = ocrWatch.elapsed;
      });

      if (candidates.isEmpty) {
        setState(() {
          _error = '텍스트를 인식하지 못했어요.';
          _running = false;
        });
        return;
      }

      final searchWatch = Stopwatch()..start();
      final results = await _searchTopCandidates(candidates);
      searchWatch.stop();

      if (!mounted) return;
      setState(() {
        _results = results;
        _searchElapsed = searchWatch.elapsed;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '실패: $e';
        _running = false;
      });
    }
  }

  /// 현재 선택된 이미지를 크롭 화면으로 넘겨 영역을 고르게 하고,
  /// 크롭본을 임시 파일로 저장해 재-OCR + 재검색한다.
  Future<void> _cropAndReSearch() async {
    if (_running) return;
    // 크롭은 항상 "원본"에서 한다. 직전 크롭본이 아니라 원본을 넘겨야
    // 재크롭 시에도 원하는 영역을 자유롭게 다시 고를 수 있다.
    final source = _originalBytes;
    if (source == null) return;

    // 크롭 화면이 열리는 동안 재진입(중복 push) 방지.
    setState(() => _running = true);

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => CoverCropScreen(imageBytes: source),
      ),
    );
    if (!mounted) return;
    if (cropped == null) {
      setState(() => _running = false); // 크롭 취소 — 상태 원복
      return;
    }

    // 크롭본을 임시 파일로 저장 → OCR 입력으로만 사용하고 finally에서 삭제.
    // 미리보기/재크롭은 삭제되는 파일이 아니라 크롭 bytes를 쓴다.
    // getTemporaryDirectory/writeAsBytes 실패 시에도 _running을 원복해야
    // 버튼이 영구 비활성으로 남지 않는다.
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File(
        '${dir.path}/cover_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tmp.writeAsBytes(cropped);
      await _runOcrPipeline(tmp.path, previewBytes: cropped);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '크롭 검색에 실패했어요: $e';
          _running = false;
        });
      }
    } finally {
      if (tmp != null && await tmp.exists()) {
        await tmp.delete();
      }
    }
  }

  /// 상위 후보 → 쿼리 변형 생성 → 각 쿼리 알라딘 검색 → 중복 제거 후 병합.
  /// 쿼리 생성/병합은 프로덕션 검색과 동일한 [buildOcrQueries] 로직을 공유.
  Future<List<BookItem>> _searchTopCandidates(
    List<TitleCandidate> candidates,
  ) async {
    final aladin = ref.read(aladinDataSourceProvider);
    final queries = buildOcrQueries(candidates.map((c) => c.text).toList());

    final resultLists = await Future.wait(
      queries.map((q) => aladin.searchByTitle(q).catchError(
            (Object _) => <BookItem>[],
          )),
    );

    return mergeCoverSearchResults(resultLists);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDefault,
        title: Text(
          '표지 OCR 실험',
          style: AppTypography.dungGeunMoHeader
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('촬영'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _running ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _previewBytes!,
                height: 200,
                fit: BoxFit.contain,
              ),
            )
          else if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_imagePath!),
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          if (_originalBytes != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _running ? null : _cropAndReSearch,
              icon: const Icon(Icons.crop),
              label: const Text('영역 직접 선택'),
            ),
          ],
          if (_running) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: AppColors.textGray),
              textAlign: TextAlign.center,
            ),
          ],
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle(
              '제목 후보 ${_candidates.length}개'
              '${_ocrElapsed != null ? ' · OCR ${_ocrElapsed!.inMilliseconds}ms' : ''}',
            ),
            const SizedBox(height: 8),
            ..._candidates.take(8).map(_candidateTile),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle(
              '검색 결과 ${_results.length}권'
              '${_searchElapsed != null ? ' · 검색 ${_searchElapsed!.inMilliseconds}ms' : ''}',
            ),
            const SizedBox(height: 8),
            ..._results.map(_bookCard),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: AppTypography.dungGeunMoSubtitle
            .copyWith(color: AppColors.textPrimary),
      );

  Widget _candidateTile(TitleCandidate c) {
    final isSearched = _candidates.indexOf(c) < searchCandidateCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSearched ? AppColors.primary : AppColors.textGray,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c.score.toStringAsFixed(0),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.text,
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'h${c.height.toStringAsFixed(0)}',
            style: AppTypography.wantedSansCaption
                .copyWith(color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _bookCard(BookItem book) {
    return Card(
      color: AppColors.backgroundWhite,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: book.cover.isEmpty
            ? const SizedBox(width: 44, child: Icon(Icons.book))
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: book.cover,
                  width: 44,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          book.title,
          style: AppTypography.dungGeunMoBody
              .copyWith(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          book.author,
          style: AppTypography.wantedSansCaption
              .copyWith(color: AppColors.textGray),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          ref.read(bookSearchProvider.notifier).selectBook(book);
          context.push(Routes.addBook);
        },
      ),
    );
  }
}
