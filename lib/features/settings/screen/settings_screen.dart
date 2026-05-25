import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/datasource/member_datasource.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/pixel_shadow_box.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _nickname = '';
  bool _editingNickname = false;
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
    setState(() { _nickname = n; _nicknameCtrl.text = n; });
  }

  Future<void> _saveNickname() async {
    final newNick = _nicknameCtrl.text.trim();
    if (newNick.isEmpty) return;
    try {
      final ds = MemberDataSource(ref.read(dioProvider));
      final updated = await ds.updateNickname(newNick);
      await ref.read(secureStorageProvider).write(key: 'nickname', value: updated);
      setState(() { _nickname = updated; _editingNickname = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('닉네임 변경 실패: $e')));
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text('설 정',
                      style: AppTypography.dungGeunMoHeader
                          .copyWith(color: AppColors.textPrimary)),
                ],
              ),
            ),

            // Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text('$_nickname님,\n안녕하세요!',
                  style: AppTypography.dungGeunMoHomeTitle
                      .copyWith(color: AppColors.textPrimary)),
            ),

            // Nickname section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('닉네임',
                      style: AppTypography.dungGeunMoSubtitle
                          .copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (_editingNickname) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nicknameCtrl,
                            style: AppTypography.wantedSansBody
                                .copyWith(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(
                                      color: AppColors.borderBlack)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PixelShadowButton(
                          onTap: _saveNickname,
                          backgroundColor: AppColors.primary,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text('저장',
                                style: AppTypography.dungGeunMoBody
                                    .copyWith(color: AppColors.textWhite)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PixelShadowButton(
                          onTap: () =>
                              setState(() => _editingNickname = false),
                          backgroundColor: AppColors.backgroundGray,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text('취소',
                                style: AppTypography.dungGeunMoBody
                                    .copyWith(
                                        color: AppColors.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Row(
                      children: [
                        Text(_nickname,
                            style: AppTypography.wantedSansBody
                                .copyWith(color: AppColors.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _editingNickname = true),
                          child: Text('수정',
                              style: AppTypography.dungGeunMoSubtitle
                                  .copyWith(color: AppColors.textGray)),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Terms & Privacy
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {}, // URL launch Phase 6에서 추가
                    child: Text('서비스 이용약관',
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textGray)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Text('개인정보 처리방침',
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textGray)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Text('회원탈퇴',
                        style: AppTypography.wantedSansBodySmall
                            .copyWith(color: AppColors.textGray)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logout button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: _logout,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderBlack),
                  ),
                  child: Text('로그아웃',
                      style: AppTypography.dungGeunMoBody
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
