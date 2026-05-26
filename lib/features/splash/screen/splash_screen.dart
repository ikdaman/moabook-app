import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
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
    if (!mounted) return;
    context.go(isLoggedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Android 원본 SplashScreen: 단색 배경만 표시한 채 즉시 라우팅.
    return const ColoredBox(color: AppColors.backgroundDefault);
  }
}
