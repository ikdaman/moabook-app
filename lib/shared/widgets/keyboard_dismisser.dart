import 'package:flutter/material.dart';

/// 자식 트리의 빈 공간을 탭하면 현재 포커스를 해제해 키보드를 내린다.
/// `behavior: opaque` 라서 자식 [GestureDetector]/[TextField]/버튼의 hit 는
/// 자식 detector 가 먼저 잡아 정상 동작한다.
class KeyboardDismisser extends StatelessWidget {
  final Widget child;

  const KeyboardDismisser({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
