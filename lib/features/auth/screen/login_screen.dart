import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/login_state.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/retro_loading.dart';
import '../provider/auth_provider.dart';

const _termsUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a98025a529d8e3bb765d2a';
const _privacyUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a9809caafdf17937d5dc80';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
            'provider': state.provider,
            'providerId': state.providerId,
          },
        );
      } else if (state is LoginError && state.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message)),
        );
      }
    });

    final loginState = ref.watch(loginStateProvider);
    final isLoading = loginState is LoginLoading;
    final auth = ref.read(authNotifierProvider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 밝은 배경 → 상태바 아이콘/텍스트 어둡게(검정).
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
      ),
      child: Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const Spacer(),
                Image.asset(
                  'assets/images/book_logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 12),
                Text(
                  '모아북',
                  style: AppTypography.dungGeunMoHomeTitle
                      .copyWith(color: AppColors.textPrimary),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _SocialButton(
                        iconAsset: 'assets/images/kakao_logo.svg',
                        label: '카카오 로그인',
                        onTap: isLoading ? null : auth.kakaoLogin,
                      ),
                      const SizedBox(height: 12),
                      _SocialButton(
                        iconAsset: 'assets/images/naver_logo.svg',
                        label: '네이버 로그인',
                        onTap: isLoading ? null : auth.naverLogin,
                      ),
                      const SizedBox(height: 12),
                      _SocialButton(
                        iconAsset: 'assets/images/google_logo.svg',
                        label: '구글 로그인',
                        onTap: isLoading ? null : auth.googleLogin,
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 12),
                        SignInWithAppleButton(
                          onPressed: isLoading ? () {} : auth.appleLogin,
                          text: 'Apple로 로그인',
                          height: 48,
                          style: SignInWithAppleButtonStyle.black,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(8)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('가입시 ',
                          style: AppTypography.wantedSansBodySmall
                              .copyWith(color: AppColors.textPrimary)),
                      _Term(text: '이용약관', onTap: () => _open(_termsUrl)),
                      Text(' 및 ',
                          style: AppTypography.wantedSansBodySmall
                              .copyWith(color: AppColors.textPrimary)),
                      _Term(text: '개인정보처리방침', onTap: () => _open(_privacyUrl)),
                      Text('에 동의하게 됩니다.',
                          style: AppTypography.wantedSansBodySmall
                              .copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
            if (isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: RetroLoading(fillBackground: false),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: PixelShadowButton(
        onTap: onTap ?? () {},
        backgroundColor: AppColors.backgroundWhite,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(iconAsset, width: 20, height: 20),
            const SizedBox(width: 8),
            Text(label,
                style: AppTypography.dungGeunMoSubtitle
                    .copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _Term extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Term({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        style: AppTypography.wantedSansBodySmall.copyWith(
          color: AppColors.textPrimary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.textPrimary,
        ),
      ),
    );
  }
}
