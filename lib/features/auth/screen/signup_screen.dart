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

  /// 중복 안내가 떠 있는 동안 마지막으로 제출했던 닉네임.
  /// 닉네임을 그대로 둔 채 완료를 다시 누르면 재요청을 막는다.
  String? _rejectedNickname;

  @override
  void initState() {
    super.initState();
    // 같은 닉네임으로 다시 완료를 누를 수 있도록 입력 변경을 감지한다.
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // 닉네임을 수정하면 중복 차단을 해제한다.
    if (_rejectedNickname != null &&
        _controller.text.trim() != _rejectedNickname) {
      _rejectedNickname = null;
    }
  }

  void _onComplete() {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) return;

    final signupState = ref.read(signupStateProvider);
    // 제출 진행 중이거나, 이미 중복으로 거절된 동일 닉네임이면 재요청 차단.
    if (signupState is SignupLoading) return;
    if (signupState is SignupNicknameDuplicate &&
        nickname == _rejectedNickname) {
      return;
    }

    _rejectedNickname = null;
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
      } else if (state is SignupNicknameDuplicate) {
        // 이 닉네임으로는 완료 재요청을 막는다(수정 전까지).
        _rejectedNickname = _controller.text.trim();
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
