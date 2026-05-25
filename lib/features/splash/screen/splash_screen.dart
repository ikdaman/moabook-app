import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/auth/provider/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // 로고를 최소 1초 표시
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final isLoggedIn = await ref.read(authRepositoryProvider).isLoggedIn();
    if (!mounted) return;

    context.go(isLoggedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: Center(
        child: Text(
          '모아북',
          style: AppTypography.dungGeunMoHomeTitle
              .copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
