import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'pixel_popup.dart';

/// Android `CalendarBottomSheet` 동등 - 픽셀풍 월 달력 + 날짜 선택.
/// 사용: showDialog → CalendarBottomSheet(...). [allowDeselect] true 시 동일 날짜
/// 재선택으로 null 반환 가능 ("FINISH" 날짜용).
class CalendarBottomSheet extends StatefulWidget {
  final DateTime initial;
  final bool allowDeselect;
  final ValueChanged<DateTime?> onConfirm;
  final VoidCallback onDismiss;

  const CalendarBottomSheet({
    super.key,
    required this.initial,
    required this.onConfirm,
    required this.onDismiss,
    this.allowDeselect = false,
  });

  @override
  State<CalendarBottomSheet> createState() => _CalendarBottomSheetState();
}

class _CalendarBottomSheetState extends State<CalendarBottomSheet> {
  late DateTime _viewMonth;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _viewMonth = DateTime(widget.initial.year, widget.initial.month);
  }

  void _prevMonth() {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));
  }

  void _nextMonth() {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));
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
              // Android 원본 CalendarPicker: Material KeyboardArrowLeft/Right
              // IconButton + 타이틀 "YYYY년 M월"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(
                      Icons.keyboard_arrow_left,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: '이전 달',
                  ),
                  Text(
                    '${_viewMonth.year}년 ${_viewMonth.month}월',
                    style: AppTypography.dungGeunMoPopupTitle
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(
                      Icons.keyboard_arrow_right,
                      color: AppColors.textPrimary,
                    ),
                    tooltip: '다음 달',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: ['일', '월', '화', '수', '목', '금', '토']
                    .map((d) => Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              d,
                              style: AppTypography.dungGeunMoTag
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              _buildMonthGrid(),
              const SizedBox(height: 16),
              PixelPopupActions(
                cancelLabel: '취소',
                confirmLabel: '확인',
                onCancel: widget.onDismiss,
                onConfirm: () {
                  if (widget.allowDeselect &&
                      _selected != null &&
                      _isSameDay(_selected!, widget.initial)) {
                    widget.onConfirm(null);
                  } else {
                    widget.onConfirm(_selected);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildMonthGrid() {
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final last = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final leading = first.weekday % 7; // Sun=0
    final totalCells = ((leading + last.day) / 7).ceil() * 7;
    final rows = <Widget>[];
    for (int row = 0; row < totalCells / 7; row++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        final dayNum = cellIndex - leading + 1;
        if (dayNum < 1 || dayNum > last.day) {
          cells.add(const Expanded(child: SizedBox(height: 34)));
        } else {
          final date =
              DateTime(_viewMonth.year, _viewMonth.month, dayNum);
          final isSelected = _selected != null && _isSameDay(_selected!, date);
          cells.add(Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selected = date),
              child: Container(
                height: 34,
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                color: isSelected
                    ? AppColors.primary
                    : Colors.transparent,
                child: Text(
                  '$dayNum',
                  style: AppTypography.dungGeunMoSubtitle.copyWith(
                    color: isSelected
                        ? AppColors.textWhite
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ));
        }
      }
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }
}
