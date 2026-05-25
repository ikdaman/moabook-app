import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../book_search/provider/book_search_provider.dart';

class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key});

  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends ConsumerState<BarcodeScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
      detectionSpeed: DetectionSpeed.normal,
      autoStart: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_handled) _controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _controller.stop();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final isbn = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => _isIsbn13(v), orElse: () => null);
    if (isbn == null) return;

    _handled = true;
    await _controller.stop();

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    final ok = await ref
        .read(bookSearchProvider.notifier)
        .searchByIsbn(isbn);

    if (!mounted) return;

    if (ok) {
      context.pushReplacement(Routes.addBook);
    } else {
      final msg = ref.read(bookSearchProvider).error ?? '검색에 실패했어요.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      // 사용자가 다시 시도할 수 있도록 스캐너 재가동
      _handled = false;
      await _controller.start();
    }
  }

  static bool _isIsbn13(String? value) {
    if (value == null) return false;
    if (value.length != 13) return false;
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return false;
    return value.startsWith('978') || value.startsWith('979');
  }

  /// 화면 크기 기반 스캔 박스. MobileScanner.scanWindow + 오버레이가 공유.
  static Rect _calcBoxRect(Size size) {
    final boxWidth = size.width * 0.8;
    final boxHeight = size.height * 0.3;
    final left = (size.width - boxWidth) / 2;
    final top = size.height * 0.3;
    return Rect.fromLTWH(left, top, boxWidth, boxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(bookSearchProvider.select((s) => s.isLoading));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boxRect = _calcBoxRect(constraints.biggest);
            return Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                  scanWindow: boxRect,
                  errorBuilder: (context, error) =>
                      _CameraErrorView(error: error),
                ),
                _ScanOverlay(box: boxRect),
                // ── Top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '바코드 스캔',
                        style: AppTypography.dungGeunMoHeader
                            .copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (_, state, _) {
                          final torchOn = state.torchState == TorchState.on;
                          return GestureDetector(
                            onTap: () => _controller.toggleTorch(),
                            child: Icon(
                              torchOn ? Icons.flash_on : Icons.flash_off,
                              color: Colors.white,
                              size: 28,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: SizedBox.expand(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 어두운 오버레이 + 중앙 스캔 박스
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.box});
  final Rect box;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _OverlayPainter(box)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: box.top - 64,
            child: Column(
              children: [
                Text(
                  '책의 바코드 영역을 맞춰주세요.',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.box);
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.8);
    final hole = Path()..addRect(box);
    final full = Path()..addRect(Offset.zero & size);
    final diff = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(diff, overlay);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(box, border);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.box != box;
}

/// 카메라 권한 거부/카메라 오류 상태 화면
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: AppColors.backgroundDefault,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isPermissionDenied ? '카메라 권한이 필요해요' : '카메라를 사용할 수 없어요',
            style: AppTypography.dungGeunMoHeader
                .copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isPermissionDenied
                ? '바코드 스캔 기능을 사용하려면\n설정 → 모아북 → 카메라 권한을 허용해 주세요.'
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
