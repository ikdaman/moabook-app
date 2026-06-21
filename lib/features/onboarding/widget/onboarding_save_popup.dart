import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/book_item.dart';
import '../../../shared/widgets/pixel_popup.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';

class OnboardingSaveResult {
  final bool saved;
  final String? reason;
  const OnboardingSaveResult({required this.saved, this.reason});
}

Future<OnboardingSaveResult?> showOnboardingSavePopup(
  BuildContext context,
  BookItem book,
) {
  return showDialog<OnboardingSaveResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: SingleChildScrollView(child: _OnboardingSavePopup(book: book)),
    ),
  );
}

class _OnboardingSavePopup extends StatefulWidget {
  const _OnboardingSavePopup({required this.book});
  final BookItem book;

  @override
  State<_OnboardingSavePopup> createState() => _OnboardingSavePopupState();
}

class _OnboardingSavePopupState extends State<_OnboardingSavePopup> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PixelPopup(
      onDismiss: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('책 추가',
              style: AppTypography.dungGeunMoPopupTitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text(widget.book.title,
              style: AppTypography.wantedSansBody
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Text('*읽고 싶은 책이에요.',
              style: AppTypography.dungGeunMoSubtitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 160,
            color: AppColors.backgroundWhite,
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                TextField(
                  controller: _reasonCtrl,
                  onChanged: (v) {
                    if (v.length > 400) {
                      _reasonCtrl.text = v.substring(0, 400);
                      _reasonCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: _reasonCtrl.text.length));
                    }
                    setState(() {});
                  },
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTypography.wantedSansBody
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '왜 이 책을 읽고 싶으신가요?\n한 줄만 적어보세요.',
                    hintStyle: AppTypography.wantedSansBody.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(bottom: 20),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Text('${_reasonCtrl.text.length}/400',
                      style: AppTypography.wantedSansBodySmall.copyWith(
                          fontSize: 10,
                          color: AppColors.textPrimary.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: PixelShadowButton(
              onTap: () {
                final r = _reasonCtrl.text.trim();
                Navigator.of(context).pop(
                  OnboardingSaveResult(saved: true, reason: r.isEmpty ? null : r),
                );
              },
              backgroundColor: AppColors.backgroundGray,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text('SAVE',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
