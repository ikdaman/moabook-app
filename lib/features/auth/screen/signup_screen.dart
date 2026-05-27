import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/signup_state.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/title_bar.dart';
import '../provider/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String socialToken;
  final String provider;
  final String providerId;

  const SignupScreen({
    super.key,
    required this.socialToken,
    required this.provider,
    required this.providerId,
  });

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onComplete() {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) return;
    ref
        .read(authNotifierProvider.notifier)
        .signup(
          socialToken: widget.socialToken,
          provider: widget.provider,
          providerId: widget.providerId,
          nickname: nickname,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signupStateProvider, (_, state) {
      if (state is SignupSuccess) {
        context.go(Routes.home);
      } else if (state is SignupError && state.message.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message)));
      }
    });

    final signupState = ref.watch(signupStateProvider);
    final isDuplicate = signupState is SignupNicknameDuplicate;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: KeyboardDismisser(
        child: SafeArea(
          child: Column(
            children: [
              TitleBar(
                title: '닉네임 입력',
                showBackButton: true,
                onBack: () => context.pop(),
                rightText: '완료',
                onRight: _onComplete,
              ),
              const SizedBox(height: 60),
              Text(
                '닉네임을 입력해주세요.',
                style: AppTypography.dungGeunMoHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelShadowBox(
                      backgroundColor: AppColors.backgroundWhite,
                      contentAlignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: AppTypography.wantedSansBody.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (isDuplicate) ...[
                      const SizedBox(height: 6),
                      Text(
                        '중복된 닉네임이에요.',
                        style: AppTypography.dungGeunMoTag.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '닉네임을 다시 확인해주세요.',
                        style: AppTypography.dungGeunMoTag.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
