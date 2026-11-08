import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router/routes.dart';
import '../../../domain/model/login_state.dart';
import '../provider/auth_provider.dart';

const _termsUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a98025a529d8e3bb765d2a';
const _privacyUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a9809caafdf17937d5dc80';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});
  static const palette = DesignPalette(Mood.a);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message)));
      }
    });

    final loginState = ref.watch(loginStateProvider);
    final isLoading = loginState is LoginLoading;
    final auth = ref.read(authNotifierProvider.notifier);

    return Theme(
      data: palette.theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: PopScope(
          canPop: !isLoading,
          child: Scaffold(
            backgroundColor: palette.background,
            body: SafeArea(
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: isLoading,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 46).clamp(
                              0,
                              double.infinity,
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MOABOOK / LOG IN',
                                  style: palette.text(
                                    10,
                                    mono: true,
                                    color: palette.muted,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: palette.ink,
                                ),
                                const Spacer(),
                                const SizedBox(height: 32),
                                Text(
                                  '모아북',
                                  style: palette.text(
                                    38,
                                    serif: true,
                                    weight: 600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '책과 함께한 시간을\n모아보세요.',
                                  style: palette.text(
                                    28,
                                    serif: true,
                                    weight: 600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '읽고 싶은 책부터 오래 기억할 문장까지.\n나만의 서가에 차곡차곡 담아보세요.',
                                  style: palette.text(13, color: palette.muted),
                                ),
                                const SizedBox(height: 40),
                                const Spacer(),
                                _SocialButton(
                                  iconAsset: 'assets/images/kakao_logo.svg',
                                  label: '카카오 로그인',
                                  onTap: isLoading ? null : auth.kakaoLogin,
                                ),
                                const SizedBox(height: 10),
                                _SocialButton(
                                  iconAsset: 'assets/images/naver_logo.svg',
                                  label: '네이버 로그인',
                                  onTap: isLoading ? null : auth.naverLogin,
                                ),
                                const SizedBox(height: 10),
                                _SocialButton(
                                  iconAsset: 'assets/images/google_logo.svg',
                                  label: '구글 로그인',
                                  onTap: isLoading ? null : auth.googleLogin,
                                ),
                                if (defaultTargetPlatform ==
                                    TargetPlatform.iOS) ...[
                                  const SizedBox(height: 10),
                                  SignInWithAppleButton(
                                    onPressed: isLoading
                                        ? () {}
                                        : auth.appleLogin,
                                    text: 'Apple로 로그인',
                                    height: 54,
                                    style: SignInWithAppleButtonStyle.black,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '가입시 ',
                                      style: palette.text(
                                        11,
                                        color: palette.muted,
                                      ),
                                    ),
                                    _Term(
                                      text: '이용약관',
                                      onTap: () => _open(_termsUrl),
                                    ),
                                    Text(
                                      ' 및 ',
                                      style: palette.text(
                                        11,
                                        color: palette.muted,
                                      ),
                                    ),
                                    _Term(
                                      text: '개인정보처리방침',
                                      onTap: () => _open(_privacyUrl),
                                    ),
                                    Text(
                                      '에 동의하게 됩니다.',
                                      style: palette.text(
                                        11,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () => context.go(Routes.onboarding),
                                    child: Text(
                                      '모아북 처음부터 둘러보기',
                                      style: palette.text(
                                        12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isLoading)
                    Positioned.fill(
                      child: AbsorbPointer(
                        child: ColoredBox(
                          color: const Color(0x33000000),
                          child: Center(
                            child: Semantics(
                              label: '로그인 중',
                              child: CircularProgressIndicator(
                                color: palette.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
    const palette = DesignPalette(Mood.a);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.ink,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: palette.ink, width: 1.3),
          shape: const RoundedRectangleBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(iconAsset, width: 20, height: 20),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: palette.text(14, weight: 600))),
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
        style: const DesignPalette(
          Mood.a,
        ).text(11).copyWith(decoration: TextDecoration.underline),
      ),
    );
  }
}
