// 갤러리 공유(ACTION_SEND) 플로우 상태 관리.
//
// 네이티브 ShareActivity가 넘긴 이미지 경로를 받아
// OCR → 알라딘 검색 → 후보 노출 → 선택 즉시 '읽고 싶은 책' 저장까지 진행한다.
// 본앱 엔진과 무관한 별도 엔진(shareMain)에서만 사용.

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_client.dart';
import '../../../data/datasource/aladin_datasource.dart';
import '../../../data/datasource/mybook_datasource.dart';
import '../../../domain/model/book_item.dart';
import '../../cover_ocr/service/book_cover_ocr.dart';
import '../../cover_ocr/service/cover_ocr_search.dart';

enum ShareImportStep { loading, pickBook, saved, error }

enum ShareImportError {
  /// 공유 이미지를 네이티브에서 받지 못함.
  imageFailed,

  /// OCR로 읽은 텍스트가 없음.
  noText,

  /// 검색 결과 0건.
  noResult,

  /// 네트워크/서버 오류.
  network,

  /// 로그인 토큰 없음(또는 만료).
  notLoggedIn,
}

class ShareImportState {
  final ShareImportStep step;
  final ShareImportError? error;
  final List<BookItem> results;
  final BookItem? savedBook;
  final bool isSaving;

  const ShareImportState({
    this.step = ShareImportStep.loading,
    this.error,
    this.results = const [],
    this.savedBook,
    this.isSaving = false,
  });

  ShareImportState copyWith({
    ShareImportStep? step,
    ShareImportError? error,
    List<BookItem>? results,
    BookItem? savedBook,
    bool? isSaving,
  }) => ShareImportState(
    step:      step      ?? this.step,
    error:     error     ?? this.error,
    results:   results   ?? this.results,
    savedBook: savedBook ?? this.savedBook,
    isSaving:  isSaving  ?? this.isSaving,
  );
}

class ShareImportNotifier extends Notifier<ShareImportState> {
  static const channel = MethodChannel('project.side.ikdaman/share_import');

  @override
  ShareImportState build() => const ShareImportState();

  void _fail(ShareImportError kind) {
    state = ShareImportState(step: ShareImportStep.error, error: kind);
  }

  /// 시트 진입 시 1회 호출: 이미지 수신 → 로그인 확인 → OCR → 검색.
  Future<void> start() async {
    state = const ShareImportState();

    final token =
        await const FlutterSecureStorage().read(key: 'access_token');
    if (token == null || token.isEmpty) {
      _fail(ShareImportError.notLoggedIn);
      return;
    }

    String? imagePath;
    try {
      imagePath = await channel.invokeMethod<String>('getSharedImage');
    } on PlatformException {
      imagePath = null;
    }
    if (imagePath == null) {
      _fail(ShareImportError.imageFailed);
      return;
    }

    final List<TitleCandidate> candidates;
    try {
      candidates = await recognizeBookCover(imagePath);
    } catch (_) {
      _fail(ShareImportError.imageFailed);
      return;
    }
    if (candidates.isEmpty) {
      _fail(ShareImportError.noText);
      return;
    }

    final queries = buildOcrQueries(candidates.map((c) => c.text).toList());
    final aladin = AladinDataSource();
    var failedQueries = 0;
    final resultLists = await Future.wait(
      queries.map(
        (q) => aladin.searchByTitle(q).catchError((Object _) {
          failedQueries++;
          return <BookItem>[];
        }),
      ),
    );
    final merged = mergeCoverSearchResults(resultLists);

    if (merged.isEmpty) {
      // 전 쿼리가 실패했으면 결과 없음이 아니라 네트워크 문제로 안내.
      _fail(queries.isNotEmpty && failedQueries == queries.length
          ? ShareImportError.network
          : ShareImportError.noResult);
      return;
    }

    state = ShareImportState(
      step: ShareImportStep.pickBook,
      results: merged,
    );
  }

  /// 책 탭 → 즉시 '읽고 싶은 책'으로 저장(historyInfo 없음).
  Future<void> save(BookItem book) async {
    if (state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      final dio = createDioClient(const FlutterSecureStorage());
      await MyBookDataSourceImpl(dio)
          .saveMyBook({'bookInfo': book.toSaveRequestBookInfo()});
      state = ShareImportState(
        step: ShareImportStep.saved,
        savedBook: book,
      );
    } on DioException catch (e) {
      _fail(e.response?.statusCode == 401
          ? ShareImportError.notLoggedIn
          : ShareImportError.network);
    } catch (_) {
      _fail(ShareImportError.network);
    }
  }

  Future<void> openApp() async {
    try {
      await channel.invokeMethod<void>('openMainApp');
    } on PlatformException {
      // 열기 실패 시 그냥 닫는다.
      await close();
    }
  }

  Future<void> close() async {
    try {
      await channel.invokeMethod<void>('close');
    } on PlatformException {
      // 무시: 액티비티가 이미 종료된 경우.
    }
  }
}

final shareImportProvider =
    NotifierProvider<ShareImportNotifier, ShareImportState>(
        ShareImportNotifier.new);
