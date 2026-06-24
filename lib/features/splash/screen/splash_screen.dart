import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/router/routes.dart';
import '../../../features/onboarding/onboarding_prefs.dart';
import '../../../app/theme/app_colors.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    final isLoggedIn = await ref.read(authRepositoryProvider).isLoggedIn();
    if (isLoggedIn) {
      if (!mounted) return;
      context.go(Routes.home);
      return;
    }
    // 미로그인: 온보딩은 설치 후 '한 번만'. 이미 봤으면 로그인으로 직행.
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(kOnboardingSeenKey) ?? false;
    if (!mounted) return;
    context.go(seen ? Routes.login : Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    // Android 원본 SplashScreen: 단색 배경만 표시한 채 즉시 라우팅.
    return const ColoredBox(color: AppColors.backgroundDefault);
  }
}
