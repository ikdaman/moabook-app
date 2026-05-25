import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/login_state.dart';
import '../provider/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(loginStateProvider, (_, state) {
      if (state is LoginSuccess) {
        context.go(Routes.home);
      } else if (state is LoginSignupRequired) {
        context.go(
          Routes.signup,
          extra: {
            'socialToken': state.socialToken,
            'provider':    state.provider,
            'providerId':  state.providerId,
          },
        );
      } else if (state is LoginError && state.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message)),
        );
      }
    });

    final loginState = ref.watch(loginStateProvider);
    final isLoading  = loginState is LoginLoading;
    final auth = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // 로고
            Text('모아북', style: AppTypography.dungGeunMoHomeTitle
                .copyWith(color: AppColors.primary)),
            const Spacer(),
            // 소셜 로그인 버튼들
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _SocialButton(
                    label: '카카오 로그인',
                    color: const Color(0xFFFEE500),
                    textColor: Colors.black87,
                    onTap: isLoading ? null : auth.kakaoLogin,
                  ),
                  const SizedBox(height: 12),
                  _SocialButton(
                    label: '네이버 로그인',
                    color: const Color(0xFF03C75A),
                    textColor: Colors.white,
                    onTap: isLoading ? null : auth.naverLogin,
                  ),
                  const SizedBox(height: 12),
                  _SocialButton(
                    label: '구글 로그인',
                    color: Colors.white,
                    textColor: Colors.black87,
                    onTap: isLoading ? null : auth.googleLogin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            if (isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppColors.borderBlack),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: AppTypography.dungGeunMoBody),
      ),
    );
  }
}
