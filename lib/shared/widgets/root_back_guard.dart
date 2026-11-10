import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool handleAppNavigationNotification(NavigationNotification notification) {
  // A root Navigator can emit false after a nested Navigator's PopScope emits
  // true. Keep Android back in Flutter so route guards always receive it.
  SystemNavigator.setFrameworkHandlesBack(
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ||
        notification.canHandlePop,
  );
  return true;
}

/// Keeps a root screen from closing Android on a single back press.
class RootBackGuard extends StatefulWidget {
  const RootBackGuard({
    super.key,
    required this.child,
    this.blocked = false,
    this.onBack,
  });

  final Widget child;
  final bool blocked;
  final VoidCallback? onBack;

  @override
  State<RootBackGuard> createState() => _RootBackGuardState();
}

class _RootBackGuardState extends State<RootBackGuard> {
  Timer? _exitTimer;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<bool> _back() async {
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    if (widget.blocked) return true;
    if (Navigator.of(context).canPop()) return false;
    if (widget.onBack != null) {
      _exitTimer?.cancel();
      widget.onBack!();
      return true;
    }
    if (!_android) return false;
    if (_exitTimer?.isActive ?? false) {
      _exitTimer?.cancel();
      await SystemNavigator.pop();
    } else {
      _exitTimer = Timer(const Duration(seconds: 2), () {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('뒤로가기를 한 번 더 누르면 종료돼요.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final content = PopScope(
      canPop:
          !widget.blocked &&
          (Navigator.of(context).canPop() ||
              (!_android && widget.onBack == null)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: widget.child,
    );
    return Router.maybeOf(context) == null
        ? content
        : BackButtonListener(onBackButtonPressed: _back, child: content);
  }
}
