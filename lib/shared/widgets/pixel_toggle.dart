import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// 픽셀 아트 스타일 ON/OFF 토글. 모서리 직각 + 하드 보더로 레트로 룩 유지.
class PixelToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const PixelToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static const _width = 52.0;
  static const _height = 28.0;
  static const _knob = 22.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(!value) : null,
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.backgroundGray,
            border: Border.all(color: AppColors.borderBlack),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 120),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _knob,
              height: _knob,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                border: Border.all(color: AppColors.borderBlack),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
