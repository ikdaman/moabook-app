import 'package:flutter/material.dart';

/// Slide between shelf sections, then let the parent start its remote refresh.
class ShelfSectionTransition extends StatefulWidget {
  const ShelfSectionTransition({
    super.key,
    required this.child,
    required this.direction,
    required this.onCompleted,
  });
  final Widget child;
  final int direction;
  final VoidCallback onCompleted;

  @override
  State<ShelfSectionTransition> createState() => _ShelfSectionTransitionState();
}

class _ShelfSectionTransitionState extends State<ShelfSectionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final CurvedAnimation progress;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    progress = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  }

  Widget? outgoing;

  @override
  void didUpdateWidget(covariant ShelfSectionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key == widget.child.key) return;
    if (widget.direction == 0) {
      outgoing = null;
      controller.stop();
      return;
    }
    outgoing = oldWidget.child;
    controller
        .forward(from: 0)
        .orCancel
        .then((_) {
          if (!mounted) return;
          setState(() => outgoing = null);
          widget.onCompleted();
        })
        .onError<TickerCanceled>((_, _) {});
  }

  @override
  void dispose() {
    progress.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: outgoing != null,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final distance = constraints.maxWidth * widget.direction;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(
                        outgoing == null ? 0 : distance * (1 - progress.value),
                        0,
                      ),
                      child: widget.child,
                    ),
                  ),
                  if (outgoing != null)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(-distance * progress.value, 0),
                        child: outgoing,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
