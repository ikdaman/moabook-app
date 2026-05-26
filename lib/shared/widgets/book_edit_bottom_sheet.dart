import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../domain/model/my_book_detail.dart';
import 'calendar_bottom_sheet.dart';
import 'pixel_popup.dart';
import 'pixel_shadow_box.dart';

/// 책 정보 화면의 "수정" 다이얼로그 결과.
/// 모든 필드가 nullable — 변경된 항목만 채워 보낸다.
class BookEditResult {
  /// `STORE` 또는 `HISTORY`.
  final String? shelfType;
  final String? reason;
  final String? startedDate; // ISO `YYYY-MM-DD`
  final String? finishedDate;
  // CUSTOM/MANUAL 책일 때만 사용.
  final String? bookInfoTitle;
  final String? bookInfoAuthor;
  final String? bookInfoPublisher;
  final String? bookInfoPublishDate;
  final String? bookInfoIsbn;
  final int? bookInfoTotalPage;

  const BookEditResult({
    this.shelfType,
    this.reason,
    this.startedDate,
    this.finishedDate,
    this.bookInfoTitle,
    this.bookInfoAuthor,
    this.bookInfoPublisher,
    this.bookInfoPublishDate,
    this.bookInfoIsbn,
    this.bookInfoTotalPage,
  });
}

class BookEditBottomSheet extends StatefulWidget {
  final MyBookDetail detail;
  final int? initialTab; // 0 = 내 서점, 1 = 히스토리. null 이면 shelfType 으로 결정.
  final ValueChanged<BookEditResult> onConfirm;

  const BookEditBottomSheet({
    super.key,
    required this.detail,
    this.initialTab,
    required this.onConfirm,
  });

  @override
  State<BookEditBottomSheet> createState() => _BookEditBottomSheetState();
}

class _BookEditBottomSheetState extends State<BookEditBottomSheet> {
  late int _tab;
  late final TextEditingController _reason;
  late DateTime _start;
  DateTime? _end;

  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _publisher;
  DateTime? _pubDate;
  late final TextEditingController _isbn;
  late final TextEditingController _totalPage;

  bool get _isCustom {
    final s = widget.detail.bookInfo.source;
    return s == 'CUSTOM' || s == 'MANUAL';
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ??
        (widget.detail.shelfType == 'HISTORY' ? 1 : 0);
    _reason = TextEditingController(text: widget.detail.reason ?? '');
    _start = _parseDate(widget.detail.historyInfo.startedDate) ?? DateTime.now();
    _end = _parseDate(widget.detail.historyInfo.finishedDate);

    _title = TextEditingController(text: widget.detail.bookInfo.title);
    _author = TextEditingController(text: widget.detail.bookInfo.author);
    _publisher =
        TextEditingController(text: widget.detail.bookInfo.publisher ?? '');
    _pubDate = _parseDate(widget.detail.bookInfo.publishDate);
    _isbn = TextEditingController(text: widget.detail.bookInfo.isbn ?? '');
    _totalPage = TextEditingController(
        text: widget.detail.bookInfo.totalPage?.toString() ?? '');
  }

  @override
  void dispose() {
    _reason.dispose();
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _isbn.dispose();
    _totalPage.dispose();
    super.dispose();
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw.length >= 10 ? raw.substring(0, 10) : raw);
    } catch (_) {
      return null;
    }
  }

  static String _yyMMdd(DateTime d) {
    final y = (d.year % 100).toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _openCalendar({
    required DateTime initial,
    required bool allowDeselect,
    required ValueChanged<DateTime?> onPicked,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => CalendarBottomSheet(
        initial: initial,
        allowDeselect: allowDeselect,
        onDismiss: () => Navigator.of(ctx).pop(),
        onConfirm: (date) {
          Navigator.of(ctx).pop();
          onPicked(date);
        },
      ),
    );
  }

  void _submit() {
    final reason = _reason.text.trim();
    final reasonValue = reason.isEmpty ? null : reason;
    final shelf = _tab == 0 ? 'STORE' : 'HISTORY';

    int? page;
    if (_isCustom) {
      page = int.tryParse(_totalPage.text.trim());
    }

    final result = BookEditResult(
      shelfType: shelf,
      reason: reasonValue,
      startedDate: _tab == 1 ? _isoDate(_start) : null,
      finishedDate: _tab == 1 && _end != null ? _isoDate(_end!) : null,
      bookInfoTitle: _isCustom ? _title.text.trim() : null,
      bookInfoAuthor: _isCustom ? _author.text.trim() : null,
      bookInfoPublisher: _isCustom
          ? (_publisher.text.trim().isEmpty ? null : _publisher.text.trim())
          : null,
      bookInfoPublishDate:
          _isCustom && _pubDate != null ? _isoDate(_pubDate!) : null,
      bookInfoIsbn: _isCustom
          ? (_isbn.text.trim().isEmpty ? null : _isbn.text.trim())
          : null,
      bookInfoTotalPage: _isCustom ? page : null,
    );
    widget.onConfirm(result);
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
              Text('책 정보 수정',
                  style: AppTypography.dungGeunMoPopupTitle
                      .copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _tabButton(0, '내 서점'),
                  const SizedBox(width: 6),
                  _tabButton(1, '히스토리'),
                ],
              ),
              const SizedBox(height: 16),
              if (_tab == 0) _buildStoreTab() else _buildHistoryTab(),
              if (_isCustom) ...[
                const SizedBox(height: 24),
                Text('책 정보',
                    style: AppTypography.dungGeunMoSubtitle
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                _input('제목', _title),
                const SizedBox(height: 12),
                _input('작가', _author),
                const SizedBox(height: 12),
                _input('출판사', _publisher),
                const SizedBox(height: 12),
                _pubDateField(),
                const SizedBox(height: 12),
                _input('ISBN', _isbn, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _input('페이지 수', _totalPage,
                    keyboardType: TextInputType.number),
              ],
              const SizedBox(height: 32),
              PixelPopupActions(
                cancelLabel: '취소',
                confirmLabel: '확인',
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: _submit,
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
      backgroundColor:
          selected ? const Color(0xFFE4E4E4) : AppColors.backgroundGray,
      isSelected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(label,
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildStoreTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('*읽고 싶은 책이에요.',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 188,
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            border: Border.all(color: AppColors.borderBlack),
          ),
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _reason,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (v) {
              if (v.length > 400) {
                _reason.text = v.substring(0, 400);
                _reason.selection = TextSelection.fromPosition(
                    TextPosition(offset: _reason.text.length));
              }
              setState(() {});
            },
            style: AppTypography.wantedSansBody
                .copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: '읽고 싶은 이유를 작성해주세요.',
              hintStyle: AppTypography.wantedSansBody
                  .copyWith(color: AppColors.textHint),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${_reason.text.length}/400',
            style: AppTypography.dungGeunMoTag
                .copyWith(color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('독서 시작',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: PixelShadowButton(
            onTap: () => _openCalendar(
              initial: _start,
              allowDeselect: false,
              onPicked: (d) => setState(() {
                if (d != null) _start = d;
              }),
            ),
            backgroundColor: AppColors.backgroundWhite,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _yyMMdd(_start),
                  style: AppTypography.dungGeunMoBody
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('독서 종료',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: PixelShadowButton(
            onTap: () => _openCalendar(
              initial: _end ?? DateTime.now(),
              allowDeselect: true,
              onPicked: (d) => setState(() => _end = d),
            ),
            backgroundColor: AppColors.backgroundWhite,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _end != null ? _yyMMdd(_end!) : '읽는 중',
                  style: AppTypography.dungGeunMoBody.copyWith(
                    color: _end != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('읽고 싶은 이유',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _reason,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (v) {
              if (v.length > 400) {
                _reason.text = v.substring(0, 400);
                _reason.selection = TextSelection.fromPosition(
                    TextPosition(offset: _reason.text.length));
              }
              setState(() {});
            },
            style: AppTypography.wantedSansBody
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${_reason.text.length}/400',
            style: AppTypography.dungGeunMoTag
                .copyWith(color: AppColors.textHint)),
      ],
    );
  }

  Widget _input(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTypography.wantedSansBodySmall
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pubDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('출간일',
            style: AppTypography.dungGeunMoSubtitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: PixelShadowButton(
            onTap: () => _openCalendar(
              initial: _pubDate ?? DateTime.now(),
              allowDeselect: false,
              onPicked: (d) => setState(() {
                if (d != null) _pubDate = d;
              }),
            ),
            backgroundColor: AppColors.backgroundWhite,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _pubDate != null ? _yyMMdd(_pubDate!) : 'YYYY-MM-DD',
                  style: AppTypography.wantedSansBodySmall.copyWith(
                    color: _pubDate != null
                        ? AppColors.textPrimary
                        : AppColors.textGray,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<BookEditResult?> showBookEditSheet(
  BuildContext context, {
  required MyBookDetail detail,
  int? initialTab,
}) {
  return showDialog<BookEditResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => BookEditBottomSheet(
      detail: detail,
      initialTab: initialTab,
      onConfirm: (r) => Navigator.of(ctx).pop(r),
    ),
  );
}
