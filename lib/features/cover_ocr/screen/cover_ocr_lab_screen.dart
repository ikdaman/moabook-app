// 표지 OCR 실험 화면 (실험용 — 검증 후 바코드 폴백 플로우에 통합 예정)
//
// 흐름: 촬영/갤러리 → recognizeBookCover() → 제목 후보(점수순) 표시
//      → 상위 후보로 알라딘 검색 → 중복 제거 → 결과 카드 리스트

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../book_search/provider/book_search_provider.dart';
import '../service/book_cover_ocr.dart';
import '../service/cover_ocr_search.dart';

class CoverOcrLabScreen extends ConsumerStatefulWidget {
  const CoverOcrLabScreen({super.key});

  @override
  ConsumerState<CoverOcrLabScreen> createState() => _CoverOcrLabScreenState();
}

class _CoverOcrLabScreenState extends ConsumerState<CoverOcrLabScreen> {
  final _picker = ImagePicker();

  String? _imagePath;
  List<TitleCandidate> _candidates = [];
  List<BookItem> _results = [];
  bool _running = false;
  String? _error;
  Duration? _ocrElapsed;
  Duration? _searchElapsed;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;

    setState(() {
      _imagePath = file.path;
      _candidates = [];
      _results = [];
      _error = null;
      _ocrElapsed = null;
      _searchElapsed = null;
      _running = true;
    });

    try {
      final ocrWatch = Stopwatch()..start();
      final candidates = await recognizeBookCover(file.path);
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
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_imagePath!),
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
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
