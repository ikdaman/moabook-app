import 'package:flutter/material.dart';
import '../../../shared/widgets/root_back_guard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../domain/model/signup_state.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
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
  static const palette = DesignPalette(Mood.a);
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
    setState(() {
      if (_controller.text.trim() != _rejectedNickname) {
        _rejectedNickname = null;
      }
    });
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
    final isLoading = signupState is SignupLoading;
    final isDuplicate =
        signupState is SignupNicknameDuplicate &&
        _rejectedNickname == _controller.text.trim();
    final canSubmit =
        _controller.text.trim().isNotEmpty && !isLoading && !isDuplicate;
    return Theme(
      data: palette.theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: RootBackGuard(
          blocked: isLoading,
          onBack: () => context.go(Routes.login),
          child: Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: palette.background,
              foregroundColor: palette.ink,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text('닉네임 입력', style: palette.text(20, weight: 600)),
              centerTitle: false,
              leading: IconButton(
                tooltip: '로그인으로 돌아가기',
                onPressed: isLoading
                    ? null
                    : () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(Routes.login);
                        }
                      },
                icon: DesignIcon('chevron-left', color: palette.ink),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Divider(height: 1, thickness: 1, color: palette.ink),
                ),
              ),
            ),
            body: KeyboardDismisser(
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MOABOOK / YOUR NAME',
                              style: palette.text(
                                10,
                                mono: true,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              '서가에서 사용할\n이름을 알려주세요.',
                              style: palette.text(
                                28,
                                serif: true,
                                weight: 600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '모아북에서 부를 나만의 이름이에요.',
                              style: palette.text(13, color: palette.muted),
                            ),
                            const SizedBox(height: 32),
                            Text('닉네임', style: palette.text(13, weight: 600)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _controller,
                              autofocus: true,
                              enabled: !isLoading,
                              maxLength: 10,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (canSubmit) _onComplete();
                              },
                              style: palette.text(16),
                              decoration: InputDecoration(
                                hintText: '닉네임을 입력해주세요.',
                                hintStyle: palette.text(
                                  14,
                                  color: palette.muted,
                                ),
                                filled: true,
                                fillColor: palette.card,
                                counterStyle: palette.text(
                                  11,
                                  color: palette.muted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: palette.line),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(
                                    color: palette.ink,
                                    width: 1.5,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: palette.line),
                                ),
                              ),
                            ),
                            if (isDuplicate) ...[
                              const SizedBox(height: 8),
                              Text(
                                '중복된 닉네임이에요.\n닉네임을 다시 확인해주세요.',
                                style: palette.text(13, color: palette.orange),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canSubmit ? _onComplete : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.button,
                            foregroundColor: palette.onButton,
                            disabledBackgroundColor: palette.line,
                            disabledForegroundColor: palette.muted,
                            minimumSize: const Size.fromHeight(54),
                            shape: const RoundedRectangleBorder(),
                            textStyle: palette.text(15, weight: 600),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.ink,
                                  ),
                                )
                              : const Text('완료'),
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
    );
  }
}
