import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/auth/provider/auth_provider.dart';

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isLoggedIn = ref.watch(isLoggedInProvider).valueOrNull ?? false;

    void go(String route) {
      FocusManager.instance.primaryFocus?.unfocus();
      context.go(route);
    }

    void navigateIfLoggedIn(String route) {
      go(isLoggedIn ? route : Routes.login);
    }

    return Container(
      color: AppColors.backgroundDefault,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                label: '읽고 싶은 책',
                isSelected: location == Routes.home,
                onTap: () => go(Routes.home),
              ),
              _Divider(),
              _NavItem(
                label: '책 추가',
                isSelected: location == Routes.searchBook,
                onTap: () => navigateIfLoggedIn(Routes.searchBook),
              ),
              _Divider(),
              _NavItem(
                label: '히스토리',
                isSelected: location == Routes.history,
                onTap: () => navigateIfLoggedIn(Routes.history),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  bool get _highlight => widget.isSelected || _pressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: Container(
        // 고정 height 제거: 텍스트 + padding 이 박스 크기를 정하게 한다.
        // (height:20 이면 픽셀 폰트 하단이 잘렸음)
        color: _highlight ? AppColors.primary : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          widget.label,
          style: AppTypography.dungGeunMoSubtitle.copyWith(
            color: _highlight ? AppColors.textWhite : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 8,
      color: AppColors.textPrimary,
    );
  }
}
