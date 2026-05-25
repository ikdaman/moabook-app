import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/signup_state.dart';
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

  @override
  Widget build(BuildContext context) {
    ref.listen(signupStateProvider, (_, state) {
      if (state is SignupSuccess) {
        context.go(Routes.home);
      } else if (state is SignupError && state.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message)));
      }
    });

    final signupState = ref.watch(signupStateProvider);
    final isLoading   = signupState is SignupLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('닉네임을 입력해주세요',
                  style: AppTypography.dungGeunMoHeader
                      .copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '닉네임',
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide:
                        const BorderSide(color: AppColors.borderBlack),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          final nickname = _controller.text.trim();
                          if (nickname.isEmpty) return;
                          ref.read(authNotifierProvider.notifier).signup(
                                socialToken: widget.socialToken,
                                provider:    widget.provider,
                                providerId:  widget.providerId,
                                nickname:    nickname,
                              );
                        },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('시작하기',
                          style: AppTypography.dungGeunMoBody),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
