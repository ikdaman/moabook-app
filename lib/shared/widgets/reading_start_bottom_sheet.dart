import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'calendar_bottom_sheet.dart';
import 'pixel_popup.dart';
import 'pixel_shadow_box.dart';

/// 내 서점에서 "독서 시작" 클릭 시 표시되는 팝업.
/// Android 원본 `ReadingStartBottomSheet` 동등.
/// START 날짜 선택 + FINISH 는 "읽는 중" (선택 불가).
class ReadingStartBottomSheet extends StatefulWidget {
  final String bookTitle;
  final VoidCallback onDismiss;
  final VoidCallback onConfirm;

  const ReadingStartBottomSheet({
    super.key,
    required this.bookTitle,
    required this.onDismiss,
    required this.onConfirm,
  });

  @override
  State<ReadingStartBottomSheet> createState() =>
      _ReadingStartBottomSheetState();
}

class _ReadingStartBottomSheetState extends State<ReadingStartBottomSheet> {
  DateTime _startDate = DateTime.now();

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')} - ${d.month.toString().padLeft(2, '0')} - ${d.day.toString().padLeft(2, '0')}';

  Future<void> _openCalendar() {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => CalendarBottomSheet(
        initial: _startDate,
        onDismiss: () => Navigator.of(ctx).pop(),
        onConfirm: (date) {
          Navigator.of(ctx).pop();
          if (date != null) setState(() => _startDate = date);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: PixelPopup(
          onDismiss: widget.onDismiss,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '책 시작하기',
                style: AppTypography.dungGeunMoPopupTitle
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 35),
              Text(
                widget.bookTitle,
                style: AppTypography.wantedSansBody
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 30),
              _row(
                label: 'START',
                child: PixelShadowButton(
                  onTap: _openCalendar,
                  backgroundColor: AppColors.backgroundWhite,
                  child: _dateValueRow(_formatDate(_startDate),
                      color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              _row(
                label: 'FINISH',
                child: PixelShadowBox(
                  backgroundColor: AppColors.backgroundWhite,
                  child: _dateValueRow('읽는 중',
                      color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 43),
              PixelPopupActions(
                cancelLabel: '취소',
                confirmLabel: '확인',
                onCancel: widget.onDismiss,
                onConfirm: widget.onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppTypography.dungGeunMoBody
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _dateValueRow(String text, {required Color color}) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  text,
                  style: AppTypography.dungGeunMoBody.copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          color: AppColors.backgroundGray,
          alignment: Alignment.center,
          child: Text(
            '▼',
            style: AppTypography.dungGeunMoBody
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// `BookRegisterBottomSheet` 와 유사한 헬퍼.
/// 확인을 누르면 `true`, 취소/dismiss 는 `null` 반환.
Future<bool?> showReadingStartSheet(
  BuildContext context, {
  required String bookTitle,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => ReadingStartBottomSheet(
      bookTitle: bookTitle,
      onDismiss: () => Navigator.of(ctx).pop(),
      onConfirm: () => Navigator.of(ctx).pop(true),
    ),
  );
}
