import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'pixel_shadow_box.dart';

/// Android 회원탈퇴/책삭제/책 등록 팝업의 공통 셸.
/// PixelShadowBox(3px 그림자, 흰 배경) 안에 회색 헤더 + X 버튼 + 본문 컬럼.
class PixelPopup extends StatelessWidget {
  final VoidCallback onDismiss;
  final Widget child;

  const PixelPopup({super.key, required this.onDismiss, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PixelShadowBox(
        backgroundColor: AppColors.backgroundWhite,
        shadowOffset: 3,
        contentAlignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      border: Border.all(color: AppColors.borderBlack),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 29,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      border: Border.all(color: AppColors.borderBlack),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✕',
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              color: AppColors.backgroundDefault,
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 취소/확인 두 버튼이 들어가는 공용 액션 Row.
class PixelPopupActions extends StatelessWidget {
  final String confirmLabel;
  final Color confirmColor;
  final Color confirmTextColor;
  final String cancelLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const PixelPopupActions({
    super.key,
    this.confirmLabel = '확인',
    this.confirmColor = AppColors.backgroundGray,
    this.confirmTextColor = AppColors.textPrimary,
    this.cancelLabel = '취소',
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PixelShadowButton(
          onTap: onCancel,
          backgroundColor: AppColors.backgroundGray,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              cancelLabel,
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 50),
        PixelShadowButton(
          onTap: onConfirm,
          backgroundColor: confirmColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              confirmLabel,
              style: AppTypography.dungGeunMoBody
                  .copyWith(color: confirmTextColor),
            ),
          ),
        ),
      ],
    );
  }
}
