import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import 'calendar_bottom_sheet.dart';
import 'pixel_popup.dart';
import 'pixel_shadow_box.dart';

class BookRegisterResult {
  final String? reason;
  final DateTime? startDate;
  final DateTime? endDate;
  const BookRegisterResult({this.reason, this.startDate, this.endDate});
}

/// Android `BookRegisterBottomSheet` 동등.
/// 내 서점 / 히스토리 탭 토글, 이유 입력(400자) 또는 START/FINISH 날짜 선택.
class BookRegisterBottomSheet extends StatefulWidget {
  final ValueChanged<BookRegisterResult> onConfirm;
  const BookRegisterBottomSheet({super.key, required this.onConfirm});

  @override
  State<BookRegisterBottomSheet> createState() =>
      _BookRegisterBottomSheetState();
}

class _BookRegisterBottomSheetState extends State<BookRegisterBottomSheet> {
  int _tab = 0; // 0=내 서점, 1=히스토리
  final _reasonCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _yyMMdd(DateTime d) {
    final y = (d.year % 100).toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now());
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => CalendarBottomSheet(
        initial: initial,
        allowDeselect: !isStart,
        onDismiss: () => Navigator.of(ctx).pop(),
        onConfirm: (date) {
          Navigator.of(ctx).pop();
          setState(() {
            if (isStart) {
              if (date != null) _startDate = date;
            } else {
              _endDate = date;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: PixelPopup(
          onDismiss: () => Navigator.of(context).pop(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '책 추가',
                style: AppTypography.dungGeunMoPopupTitle
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _tabButton(0, '내 서점'),
                  const SizedBox(width: 6),
                  _tabButton(1, '히스토리'),
                ],
              ),
              const SizedBox(height: 16),
              if (_tab == 0)
                _buildStoreTab()
              else
                _buildHistoryTab(),
              const SizedBox(height: 20),
              PixelPopupActions(
                cancelLabel: '취소',
                confirmLabel: '확인',
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: () {
                  final reason = _reasonCtrl.text.trim();
                  final result = _tab == 0
                      ? BookRegisterResult(
                          reason: reason.isEmpty ? null : reason,
                        )
                      : BookRegisterResult(
                          reason: reason.isEmpty ? null : reason,
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                  widget.onConfirm(result);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int idx, String label) {
    final selected = _tab == idx;
    return PixelShadowButton(
      onTap: () => setState(() => _tab = idx),
      backgroundColor: selected
          ? const Color(0xFFE4E4E4)
          : AppColors.backgroundGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: AppTypography.dungGeunMoSubtitle
              .copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildStoreTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '*읽고 싶은 책이에요.',
          style: AppTypography.dungGeunMoSubtitle
              .copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 188,
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
                  hintText: '읽고 싶은 이유를 작성해주세요.',
                  hintStyle: AppTypography.wantedSansBody.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.only(bottom: 20),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  '${_reasonCtrl.text.length}/400',
                  style: AppTypography.wantedSansBodySmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '*독서 중이거나 완독한 책이에요.',
          style: AppTypography.dungGeunMoSubtitle
              .copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        _dateRow(
          label: 'START',
          dateText: _yyMMdd(_startDate),
          onTap: () => _pickDate(isStart: true),
        ),
        const SizedBox(height: 20),
        _dateRow(
          label: 'FINISH',
          dateText: _endDate != null ? _yyMMdd(_endDate!) : '읽는 중',
          onTap: () => _pickDate(isStart: false),
        ),
      ],
    );
  }

  Widget _dateRow({
    required String label,
    required String dateText,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: AppTypography.dungGeunMoBody
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: PixelShadowButton(
            onTap: onTap,
            backgroundColor: AppColors.backgroundWhite,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 28,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      dateText,
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                Container(
                  height: 28,
                  width: 28,
                  color: AppColors.backgroundGray,
                  alignment: Alignment.center,
                  child: Text(
                    '▼',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<BookRegisterResult?> showBookRegisterSheet(BuildContext context) {
  return showDialog<BookRegisterResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => BookRegisterBottomSheet(
      onConfirm: (r) => Navigator.of(ctx).pop(r),
    ),
  );
}
