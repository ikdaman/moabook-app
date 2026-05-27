import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class PixelShadowBox extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color shadowColor;
  final double shadowOffset;
  final bool showBorder;

  /// null 이면 부모 크기로 expand 하지 않고 child 크기로 shrink-wrap 한다.
  final AlignmentGeometry? contentAlignment;

  const PixelShadowBox({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.backgroundGray,
    this.shadowColor = AppColors.borderBlack,
    this.shadowOffset = 1.0,
    this.showBorder = true,
    this.contentAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: shadowOffset, bottom: shadowOffset),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(shadowOffset, shadowOffset),
              child: DecoratedBox(
                decoration: BoxDecoration(color: shadowColor),
              ),
            ),
          ),
          CustomPaint(
            painter: showBorder
                ? const _PixelBorderPainter(pressed: false)
                : null,
            child: Container(
              color: backgroundColor,
              alignment: contentAlignment,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class PixelShadowButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color shadowColor;
  final double shadowOffset;
  final bool isSelected;

  const PixelShadowButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor = AppColors.backgroundGray,
    this.shadowColor = AppColors.borderBlack,
    this.shadowOffset = 1.0,
    this.isSelected = false,
  });

  @override
  State<PixelShadowButton> createState() => _PixelShadowButtonState();
}

class _PixelShadowButtonState extends State<PixelShadowButton> {
  bool _pressed = false;

  bool get _showPressed => _pressed || widget.isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        right: _showPressed ? 0 : widget.shadowOffset,
        bottom: _showPressed ? 0 : widget.shadowOffset,
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!_showPressed)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(widget.shadowOffset, widget.shadowOffset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: widget.shadowColor),
                  ),
                ),
              ),
            CustomPaint(
              painter: _PixelBorderPainter(pressed: _showPressed),
              child: Container(
                color: widget.backgroundColor,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 상/좌: white 1px, 우/하: black 1px (normal) — pressed 시 반전
class _PixelBorderPainter extends CustomPainter {
  final bool pressed;

  const _PixelBorderPainter({required this.pressed});

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = pressed ? Colors.black : Colors.white;
    final botRight = pressed ? Colors.white : Colors.black;
    const s = 1.0;

    canvas
      ..drawLine(
        Offset(0, s / 2),
        Offset(size.width, s / 2),
        Paint()
          ..color = topLeft
          ..strokeWidth = s,
      )
      ..drawLine(
        Offset(s / 2, 0),
        Offset(s / 2, size.height),
        Paint()
          ..color = topLeft
          ..strokeWidth = s,
      )
      ..drawLine(
        Offset(0, size.height - s / 2),
        Offset(size.width, size.height - s / 2),
        Paint()
          ..color = botRight
          ..strokeWidth = s,
      )
      ..drawLine(
        Offset(size.width - s / 2, 0),
        Offset(size.width - s / 2, size.height),
        Paint()
          ..color = botRight
          ..strokeWidth = s,
      );
  }

  @override
  bool shouldRepaint(_PixelBorderPainter old) => old.pressed != pressed;
}
