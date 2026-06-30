import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'calendar_bottom_sheet.dart';
import 'pixel_popup.dart';
import 'pixel_shadow_box.dart';

/// 내 서점에서 "독서 시작" 클릭 시 표시되는 팝업.
/// START + FINISH 날짜 선택. FINISH 미선택(또는 재선택 해제) 시 "읽는 중".
class ReadingStartBottomSheet extends StatefulWidget {
  final String bookTitle;
  final VoidCallback onDismiss;
  final void Function(DateTime start, DateTime? finish) onConfirm;

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
  DateTime? _finishDate; // null = "읽는 중"

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')} - ${d.month.toString().padLeft(2, '0')} - ${d.day.toString().padLeft(2, '0')}';

  Future<void> _openStartCalendar() {
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

  Future<void> _openFinishCalendar() {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => CalendarBottomSheet(
        initial: _finishDate ?? _startDate,
        allowDeselect: true, // 같은 날 재선택 → null ("읽는 중")
        onDismiss: () => Navigator.of(ctx).pop(),
        onConfirm: (date) {
          Navigator.of(ctx).pop();
          setState(() => _finishDate = date);
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
                  onTap: _openStartCalendar,
                  backgroundColor: AppColors.backgroundWhite,
                  child: _dateValueRow(_formatDate(_startDate),
                      color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              _row(
                label: 'FINISH',
                child: PixelShadowButton(
                  onTap: _openFinishCalendar,
                  backgroundColor: AppColors.backgroundWhite,
                  child: _dateValueRow(
                    _finishDate == null ? '읽는 중' : _formatDate(_finishDate!),
                    color: _finishDate == null
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 43),
              PixelPopupActions(
                cancelLabel: '취소',
                confirmLabel: '확인',
                onCancel: widget.onDismiss,
                onConfirm: () => widget.onConfirm(_startDate, _finishDate),
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

/// 독서 시작 팝업 결과. [finish] 가 null 이면 "읽는 중".
class ReadingStartResult {
  final DateTime start;
  final DateTime? finish;
  const ReadingStartResult(this.start, this.finish);
}

/// 확인 시 선택한 START/FINISH 날짜 반환, 취소/dismiss 는 null.
Future<ReadingStartResult?> showReadingStartSheet(
  BuildContext context, {
  required String bookTitle,
}) {
  return showDialog<ReadingStartResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => ReadingStartBottomSheet(
      bookTitle: bookTitle,
      onDismiss: () => Navigator.of(ctx).pop(),
      onConfirm: (start, finish) =>
          Navigator.of(ctx).pop(ReadingStartResult(start, finish)),
    ),
  );
}
