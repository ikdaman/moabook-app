import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'pixel_shadow_box.dart';

/// Android TitleBar (~/dev/moabook/ui/.../component/TitleBar.kt) 동등.
/// 58dp 높이, 좌측 30dp 백 버튼, 가운데 제목, 우측 텍스트 액션 최대 2개.
class TitleBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String? rightText;
  final VoidCallback? onRight;
  final String? rightText2;
  final VoidCallback? onRight2;

  const TitleBar({
    super.key,
    this.title = '',
    this.showBackButton = false,
    this.onBack,
    this.rightText,
    this.onRight,
    this.rightText2,
    this.onRight2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      color: AppColors.backgroundDefault,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          if (showBackButton)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 30,
                height: 30,
                child: PixelShadowButton(
                  onTap: onBack ?? () {},
                  backgroundColor: AppColors.backgroundWhite,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/arrow_left.svg',
                      height: 16,
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Text(
              title,
              style: AppTypography.dungGeunMoHeader
                  .copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          if (rightText != null || rightText2 != null)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rightText2 != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: GestureDetector(
                        onTap: onRight2,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          rightText2!,
                          style: AppTypography.dungGeunMoBody
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  if (rightText != null)
                    GestureDetector(
                      onTap: onRight,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        rightText!,
                        style: AppTypography.dungGeunMoBody
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
