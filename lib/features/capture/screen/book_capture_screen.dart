// 통합 촬영 화면 — 인앱 카메라 프리뷰 + 셔터.
//
// 한 화면에서 두 입력을 동시에 처리한다:
// - 바코드: 프리뷰 스트림을 ML Kit 바코드 스캐너에 실시간으로 흘려
//   ISBN(EAN-13/8)이 잡히면 즉시 알라딘 조회 → 책 추가 화면으로 이동.
// - 표지: 하단 가운데 셔터로 촬영 → OCR → 알라딘 검색 → 결과 화면.
// 갤러리 버튼은 사진을 골라 표지 파이프라인으로 보낸다.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../book_search/provider/book_search_provider.dart';
import '../../cover_ocr/screen/cover_ocr_result_screen.dart';
import '../../cover_ocr/service/cover_ocr_search.dart';

class BookCaptureScreen extends ConsumerStatefulWidget {
  const BookCaptureScreen({super.key});

  @override
  ConsumerState<BookCaptureScreen> createState() => _BookCaptureScreenState();
}

class _BookCaptureScreenState extends ConsumerState<BookCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  final _picker = ImagePicker();

  bool _initFailed = false;
  bool _permissionDenied = false;

  /// 바코드가 잡혀 화면 전환이 시작됨 — 이후 모든 입력 무시.
  bool _handled = false;

  /// ML Kit 프레임 분석 중 (프레임 드랍용 가드)
  bool _analyzing = false;

  /// 셔터/갤러리 → OCR 검색 진행 중
  bool _searching = false;

  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_onFrame);
      setState(() {});
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = e.code.contains('CameraAccessDenied');
        _initFailed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_controller != null) _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_initFailed && !_handled) _initCamera();
    }
  }

  void _disposeCamera() {
    final controller = _controller;
    _controller = null;
    _torchOn = false;
    controller?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  // ── 바코드 실시간 감지 ────────────────────────────────────────────────

  Future<void> _onFrame(CameraImage image) async {
    if (_analyzing || _handled || _searching) return;
    _analyzing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final barcodes = await _barcodeScanner.processImage(inputImage);
      final isbn = barcodes
          .map((b) => b.rawValue)
          .firstWhere(_isIsbn13, orElse: () => null);
      if (isbn != null) await _onIsbnDetected(isbn);
    } catch (_) {
      // 프레임 단위 분석 실패는 무시 — 다음 프레임에서 재시도
    } finally {
      _analyzing = false;
    }
  }

  Future<void> _onIsbnDetected(String isbn) async {
    if (_handled) return;
    _handled = true;
    await _stopStream();

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {});

    final ok = await ref.read(bookSearchProvider.notifier).searchByIsbn(isbn);
    if (!mounted) return;

    if (ok) {
      context.pushReplacement(Routes.addBook);
    } else {
      final msg = ref.read(bookSearchProvider).error ?? '검색에 실패했어요.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      // 다시 시도할 수 있도록 스캔 재가동
      _handled = false;
      setState(() {});
      await _resumeStream();
    }
  }

  static bool _isIsbn13(String? value) {
    if (value == null) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return false;
    return value.startsWith('978') || value.startsWith('979');
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  Future<void> _resumeStream() async {
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isStreamingImages) {
      await controller.startImageStream(_onFrame);
    }
  }

  // ── 표지 촬영 / 갤러리 → OCR 검색 ────────────────────────────────────

  Future<void> _onShutter() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_searching || _handled) return;

    setState(() => _searching = true);
    try {
      await _stopStream();
      final file = await controller.takePicture();
      if (_torchOn) {
        _torchOn = false;
        await controller.setFlashMode(FlashMode.off);
      }
      await _searchCover(file.path);
    } catch (_) {
      _showError('촬영에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
        if (!_handled) await _resumeStream();
      }
    }
  }

  Future<void> _onGallery() async {
    if (_searching || _handled) return;

    setState(() => _searching = true);
    try {
      await _stopStream();
      final file =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file != null) await _searchCover(file.path);
    } catch (_) {
      _showError('사진을 불러오지 못했어요.');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
        if (!_handled) await _resumeStream();
      }
    }
  }

  /// OCR + 알라딘 검색을 돌리고 결과 화면으로 이동.
  /// 결과 화면에서 "다시 찍기"로 pop 하면 이 화면으로 돌아온다.
  Future<void> _searchCover(String imagePath) async {
    final aladin = ref.read(aladinDataSourceProvider);
    final results = await searchBooksByCover(imagePath, aladin);

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await context.push(
      Routes.coverOcrResult,
      extra: CoverOcrResultArgs(imagePath: imagePath, results: results),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torchOn = next);
    } on CameraException {
      // 토치 미지원 기기 — 무시
    }
  }

  // ── CameraImage → ML Kit InputImage 변환 ─────────────────────────────

  static const _deviceOrientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final sensorOrientation = controller.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      final deviceRotation =
          _deviceOrientations[controller.value.deviceOrientation];
      if (deviceRotation == null) return null;
      rotation = InputImageRotationValue.fromRawValue(
        (sensorOrientation - deviceRotation + 360) % 360,
      );
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(bookSearchProvider.select((s) => s.isLoading));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_initFailed)
            _CameraErrorView(permissionDenied: _permissionDenied)
          else
            _buildPreview(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),
                _buildGuideText(),
                const Spacer(),
                if (!_initFailed) _buildControls(),
              ],
            ),
          ),
          if (isLoading || _searching)
            const ColoredBox(
              color: Color(0x88000000),
              child: SizedBox.expand(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        '책을 찾고 있어요...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          // 세로 화면 기준 — previewSize 는 가로 기준이라 축을 바꿔준다.
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '사진 검색',
            style:
                AppTypography.dungGeunMoHeader.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '책 표지나 바코드를 찍어주세요',
        style: AppTypography.dungGeunMoSubtitle.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundIconButton(
            icon: Icons.photo_library_outlined,
            onTap: _searching ? null : _onGallery,
          ),
          _ShutterButton(onTap: _searching ? null : _onShutter),
          _RoundIconButton(
            icon: _torchOn ? Icons.flash_on : Icons.flash_off,
            onTap: _toggleTorch,
          ),
        ],
      ),
    );
  }
}

/// 하단 가운데 셔터 버튼 — 흰 링 + 흰 원.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

/// 카메라 권한 거부/초기화 실패 상태 화면
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.permissionDenied});
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDefault,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            permissionDenied ? '카메라 권한이 필요해요' : '카메라를 사용할 수 없어요',
            style: AppTypography.dungGeunMoHeader
                .copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            permissionDenied
                ? '책 촬영 기능을 사용하려면\n설정 → 모아북 → 카메라 권한을 허용해 주세요.'
                : '잠시 후 다시 시도해주세요.',
            style: AppTypography.dungGeunMoBody
                .copyWith(color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
