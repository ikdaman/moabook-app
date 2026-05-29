import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/datasource/member_datasource.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/pixel_popup.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';
import '../../../shared/widgets/pixel_toggle.dart';
import '../../../shared/widgets/title_bar.dart';
import '../../notification/provider/push_settings_provider.dart';

const _termsUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a98025a529d8e3bb765d2a';
const _privacyUrl =
    'https://scientific-ferryboat-eb1.notion.site/3354710961a9809caafdf17937d5dc80';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _nickname = '';
  bool _editing = false;
  bool _loggingOut = false;
  String? _nicknameError;
  final _nicknameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNickname() async {
    final storage = ref.read(secureStorageProvider);
    final n = await storage.read(key: 'nickname') ?? '';
    if (!mounted) return;
    setState(() {
      _nickname = n;
      _nicknameCtrl.text = n;
    });
  }

  void _validateNickname(String v) {
    final t = v.trim();
    String? err;
    if (t.isEmpty) {
      err = '닉네임을 입력해주세요.';
    } else if (t.length > 10) {
      err = '닉네임은 10자 이내로 입력해주세요.';
    }
    setState(() => _nicknameError = err);
  }

  Future<void> _saveNickname() async {
    final newNick = _nicknameCtrl.text.trim();
    if (newNick.isEmpty) return;
    if (_nicknameError != null) return;
    try {
      final ds = MemberDataSource(ref.read(dioProvider));
      final updated = await ds.updateNickname(newNick);
      await ref
          .read(secureStorageProvider)
          .write(key: 'nickname', value: updated);
      if (!mounted) return;
      setState(() {
        _nickname = updated;
        _editing = false;
        _nicknameError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('닉네임 변경 실패: $e')));
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(authNotifierProvider.notifier).logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
    if (mounted) context.go(Routes.login);
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: SingleChildScrollView(
          child: PixelPopup(
            onDismiss: () => Navigator.of(ctx).pop(false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '회원탈퇴',
                  style: AppTypography.dungGeunMoPopupTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '탈퇴하면 모든 데이터가 삭제되며\n복구할 수 없어요.\n정말로 탈퇴하시겠어요?',
                  style: AppTypography.wantedSansBody.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                PixelPopupActions(
                  cancelLabel: '취소',
                  confirmLabel: '탈퇴',
                  confirmColor: AppColors.dangerAccent,
                  confirmTextColor: AppColors.textWhite,
                  onCancel: () => Navigator.of(ctx).pop(false),
                  onConfirm: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final ds = MemberDataSource(ref.read(dioProvider));
      await ds.withdraw();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원탈퇴 실패: $e')));
      return;
    }
    // 토큰 폐기 + 로그인 화면 복귀
    await _logout();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: KeyboardDismisser(
        child: SafeArea(
          child: Column(
            children: [
              TitleBar(
                title: '설 정',
                showBackButton: true,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ).add(const EdgeInsets.only(top: 30)),
                  // 키보드 올라올 때 bottom overflow 방지 — viewport 보다 작으면
                  // Spacer 가 정상 작동해 로그아웃 버튼이 하단 고정, 클 때만 스크롤.
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_nickname.isEmpty ? "OO" : _nickname}님,\n안녕하세요!',
                                style: AppTypography.dungGeunMoHomeTitle
                                    .copyWith(color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 60),
                              SizedBox(
                                height: 32,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '닉네임',
                                      style: AppTypography.dungGeunMoBody
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_editing)
                                ..._buildEditingNickname()
                              else
                                _buildNicknameDisplay(),
                              const SizedBox(height: 60),
                              _buildPushToggle(),
                              const SizedBox(height: 36),
                              _MenuItem(
                                text: '서비스 이용약관',
                                onTap: () => _openUrl(_termsUrl),
                              ),
                              const SizedBox(height: 10),
                              _MenuItem(
                                text: '개인정보 처리방침',
                                onTap: () => _openUrl(_privacyUrl),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _withdraw,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 10,
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    '회원탈퇴',
                                    style: AppTypography.dungGeunMoTag.copyWith(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: PixelShadowButton(
                                  onTap: _loggingOut ? () {} : _logout,
                                  backgroundColor: AppColors.primary,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _loggingOut ? '로그아웃 중...' : '로그아웃',
                                        style: AppTypography.dungGeunMoBody
                                            .copyWith(
                                              color: AppColors.textWhite,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
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
    );
  }

  Widget _buildPushToggle() {
    final asyncEnabled = ref.watch(pushSettingsProvider);
    // 로딩/에러 중에도 토글은 보여야 하므로 마지막 값(없으면 ON)으로 표시.
    final enabled = asyncEnabled.valueOrNull ?? true;
    final busy = asyncEnabled.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '알림',
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        PixelShadowBox(
          backgroundColor: AppColors.backgroundWhite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '푸시 알림 받기',
                    style: AppTypography.wantedSansBody.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                PixelToggle(
                  value: enabled,
                  enabled: !busy,
                  onChanged: (v) =>
                      ref.read(pushSettingsProvider.notifier).toggle(v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '책을 잊지 않도록 모아북이 가끔 알려드려요.',
            style: AppTypography.dungGeunMoTag.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameDisplay() {
    return PixelShadowButton(
      onTap: () {
        setState(() {
          _editing = true;
          _nicknameCtrl.text = _nickname;
          _nicknameError = null;
        });
      },
      backgroundColor: AppColors.backgroundWhite,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _nickname.isEmpty ? '닉네임 없음' : _nickname,
                style: AppTypography.wantedSansBody.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '수정',
              style: AppTypography.dungGeunMoTag.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEditingNickname() {
    return [
      PixelShadowBox(
        backgroundColor: AppColors.backgroundWhite,
        contentAlignment: Alignment.centerLeft,
        child: TextField(
          controller: _nicknameCtrl,
          onChanged: _validateNickname,
          style: AppTypography.wantedSansBody.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      if (_nicknameError != null) ...[
        const SizedBox(height: 6),
        Text(
          _nicknameError!,
          style: AppTypography.dungGeunMoTag.copyWith(color: AppColors.primary),
        ),
      ],
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PixelShadowButton(
            onTap: () {
              setState(() {
                _editing = false;
                _nicknameCtrl.text = _nickname;
                _nicknameError = null;
              });
            },
            backgroundColor: AppColors.backgroundGray,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '취소',
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PixelShadowButton(
            onTap: _saveNickname,
            backgroundColor: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'SAVE',
                style: AppTypography.dungGeunMoBody.copyWith(
                  color: AppColors.textWhite,
                ),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class _MenuItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _MenuItem({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: AppTypography.dungGeunMoBody.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
