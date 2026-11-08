import 'package:flutter/material.dart';

/// Keeps the barrier and sheet mounted through their exit animations.
class SlidingSheetOverlay extends StatelessWidget {
  const SlidingSheetOverlay({
    super.key,
    required this.sheet,
    required this.identity,
    required this.barrierColor,
    required this.onDismiss,
  });

  final Widget? sheet;
  final String identity;
  final Color barrierColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: sheet == null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 200),
          child: sheet == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  key: const ValueKey('sheet-barrier'),
                  onTap: onDismiss,
                  child: SizedBox.expand(child: ColoredBox(color: barrierColor)),
                ),
        ),
      ),
      IgnorePointer(
        ignoring: sheet == null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          reverseDuration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, outgoing) => Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (final child in outgoing) IgnorePointer(child: child),
              ?current,
            ],
          ),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
          child: sheet == null
              ? const SizedBox.shrink()
              : KeyedSubtree(key: ValueKey(identity), child: sheet!),
        ),
      ),
    ],
  );
}
