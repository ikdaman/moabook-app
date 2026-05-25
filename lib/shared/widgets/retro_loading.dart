import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'pixel_shadow_box.dart';

/// Android 원본의 `RetroLoading` 컴포넌트와 동일 동작.
/// "로딩중" 텍스트 뒤에 점이 0→1→2→3개로 400ms 마다 순환.
class RetroLoading extends StatefulWidget {
  /// 전체 배경(BackgroundDefault)으로 화면을 덮을지 여부.
  final bool fillBackground;

  const RetroLoading({super.key, this.fillBackground = true});

  @override
  State<RetroLoading> createState() => _RetroLoadingState();
}

class _RetroLoadingState extends State<RetroLoading> {
  Timer? _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = PixelShadowBox(
      backgroundColor: AppColors.backgroundWhite,
      shadowOffset: 3,
      contentAlignment: null, // 텍스트 크기만큼 shrink-wrap
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Text(
          '로딩중${'.' * _dotCount}',
          style: AppTypography.dungGeunMoBody
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
    );

    if (!widget.fillBackground) return Center(child: box);

    return ColoredBox(
      color: AppColors.backgroundDefault,
      child: SizedBox.expand(child: Center(child: box)),
    );
  }
}
