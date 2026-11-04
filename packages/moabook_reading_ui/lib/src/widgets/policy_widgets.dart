import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system.dart';

/// Keeps empty positions visible rather than packing books after a removal.
class CollectionSlotGrid extends StatelessWidget {
  const CollectionSlotGrid({
    super.key,
    required this.palette,
    required this.slotBuilder,
  });
  final DesignPalette palette;
  final Widget Function(int index, double width) slotBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(100.0, (constraints.maxWidth - 24) / 3);
      return Wrap(
        spacing: (constraints.maxWidth - width * 3) / 2,
        runSpacing: 18,
        children: [
          for (var index = 0; index < 9; index++)
            SizedBox(
              key: ValueKey('collection-slot-$index'),
              width: width,
              height: width * 1.35,
              child: slotBuilder(index, width),
            ),
        ],
      );
    },
  );
}

class EmptyCollectionSlot extends StatelessWidget {
  const EmptyCollectionSlot({
    super.key,
    required this.palette,
    required this.index,
    this.onTap,
  });
  final DesignPalette palette;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${index + 1}번 빈 칸${onTap == null ? '' : ', 책 추가'}',
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorder(palette.line),
        child: Center(
          child: onTap == null
              ? const SizedBox.shrink()
              : Icon(Icons.add, size: 22, color: palette.muted),
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3;
    final path = Path()..addRect(Offset.zero & size);
    for (final metric in path.computeMetrics()) {
      for (double position = 0; position < metric.length; position += 9) {
        canvas.drawPath(
          metric.extractPath(position, math.min(position + 5, metric.length)),
          paint..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}

/// Selection is tentative until the caller confirms the surrounding sheet.
class ReadingCalendar extends StatefulWidget {
  const ReadingCalendar({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
  });
  final DesignPalette palette;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  @override
  State<ReadingCalendar> createState() => _ReadingCalendarState();
}

class _ReadingCalendarState extends State<ReadingCalendar> {
  late DateTime month = DateTime(widget.selected.year, widget.selected.month);
  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final offset = month.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + days) / 7).ceil();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () => setState(() {
                month = DateTime(month.year, month.month - 1);
              }),
              icon: Icon(Icons.chevron_left, color: p.ink),
            ),
            Text(
              '${month.year}년 ${month.month}월',
              key: const Key('calendar-month'),
              style: p.text(18, weight: 600),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () => setState(() {
                month = DateTime(month.year, month.month + 1);
              }),
              icon: Icon(Icons.chevron_right, color: p.ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final label in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Center(
                  child: Text(label, style: p.text(12, color: p.muted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = row * 7 + column - offset + 1;
                      if (day < 1 || day > days) {
                        return const SizedBox(height: 44);
                      }
                      final date = DateTime(month.year, month.month, day);
                      final selected = DateUtils.isSameDay(
                        date,
                        widget.selected,
                      );
                      return SizedBox(
                        height: 44,
                        child: Semantics(
                          label: '${month.year}년 ${month.month}월 $day일',
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey(
                              'calendar-day-${month.year}-${month.month}-$day',
                            ),
                            onTap: () => widget.onChanged(date),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              color: selected ? p.button : null,
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: p.text(
                                    14,
                                    mono: true,
                                    color: selected ? p.onButton : p.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
