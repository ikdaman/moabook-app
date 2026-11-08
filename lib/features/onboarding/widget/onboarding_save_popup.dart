import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import '../../../domain/model/book_item.dart';
import 'onboarding_book.dart';

class OnboardingSaveResult {
  final bool saved;
  final String? reason;
  const OnboardingSaveResult({required this.saved, this.reason});
}

Future<OnboardingSaveResult?> showOnboardingSavePopup(
  BuildContext context,
  BookItem book, {
  String? initialReason,
}) => showModalBottomSheet<OnboardingSaveResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const DesignPalette(Mood.a).background,
  barrierColor: Colors.black.withValues(alpha: .55),
  shape: const RoundedRectangleBorder(),
  builder: (context) => Theme(
    data: const DesignPalette(Mood.a).theme,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: math.max(
          0,
          math.min(
            620,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                MediaQuery.paddingOf(context).top -
                24,
          ),
        ),
        child: _OnboardingSavePopup(book: book, initialReason: initialReason),
      ),
    ),
  ),
);

class _OnboardingSavePopup extends StatefulWidget {
  const _OnboardingSavePopup({required this.book, this.initialReason});
  final BookItem book;
  final String? initialReason;
  @override
  State<_OnboardingSavePopup> createState() => _OnboardingSavePopupState();
}

class _OnboardingSavePopupState extends State<_OnboardingSavePopup> {
  static const palette = DesignPalette(Mood.a);
  late final _reasonCtrl = TextEditingController(
    text: widget.initialReason ?? '',
  );
  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 10, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('첫 마음 남기기', style: palette.text(19, weight: 600)),
              ),
              IconButton(
                tooltip: '책 선택 닫기',
                onPressed: () => Navigator.pop(context),
                icon: DesignIcon('x', color: palette.ink),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OnboardingBook(book: widget.book, width: 70, height: 98),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: palette.text(17, weight: 600),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.book.author,
                            style: palette.text(12, color: palette.muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.book.publisher,
                            style: palette.text(11, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: palette.line),
                const SizedBox(height: 22),
                Text(
                  '어떤 점이 마음에 남았나요?',
                  style: palette.text(21, serif: true, weight: 600),
                ),
                const SizedBox(height: 10),
                Text(
                  '추천받은 한마디, 눈길이 간 제목.\n지금 떠오른 이유를 가볍게 남겨보세요.',
                  style: palette.text(13, color: palette.muted),
                ),
                const SizedBox(height: 20),
                Text('읽고 싶은 이유 · 선택', style: palette.text(12, weight: 600)),
                const SizedBox(height: 9),
                TextField(
                  controller: _reasonCtrl,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 400,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  style: palette.text(15),
                  decoration: InputDecoration(
                    hintText: '이 책을 읽고 싶어진 순간을 적어보세요.',
                    hintStyle: palette.text(14, color: palette.muted),
                    filled: true,
                    fillColor: palette.card,
                    counterStyle: palette.text(
                      10,
                      mono: true,
                      color: palette.muted,
                    ),
                    contentPadding: const EdgeInsets.all(15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: palette.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: palette.ink, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '이유는 비워두어도 괜찮아요. 책은 로그인 후 저장돼요.',
                style: palette.text(11, color: palette.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.button,
                  foregroundColor: palette.onButton,
                  minimumSize: const Size.fromHeight(54),
                  shape: const RoundedRectangleBorder(),
                  textStyle: palette.text(15, weight: 600),
                ),
                onPressed: () {
                  final reason = _reasonCtrl.text.trim();
                  Navigator.pop(
                    context,
                    OnboardingSaveResult(
                      saved: true,
                      reason: reason.isEmpty ? null : reason,
                    ),
                  );
                },
                child: const Text('이 책으로 시작하기'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
