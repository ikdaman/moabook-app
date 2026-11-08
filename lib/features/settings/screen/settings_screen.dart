import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/router/routes.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import '../../../data/datasource/member_datasource.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
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
  static const _palette = DesignPalette(Mood.a);
  bool _savingNickname = false;
  bool _withdrawing = false;
  String _nickname = '';
  bool _editing = false;
  bool _loggingOut = false;
  String? _nicknameError;
  bool _nicknameDuplicate = false;
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
    // 입력이 바뀌면 직전 중복 안내를 해제(다시 저장 시도 가능).
    setState(() {
      _nicknameError = err;
      _nicknameDuplicate = false;
    });
  }

  Future<void> _saveNickname() async {
    final newNick = _nicknameCtrl.text.trim();
    if (_savingNickname || _withdrawing || _loggingOut) return;
    _validateNickname(newNick);
    if (_nicknameError != null) return;
    if (newNick == _nickname) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _savingNickname = true);
    try {
      final ds = MemberDataSource(ref.read(dioProvider));
      final updated = await ds.updateNickname(newNick);
      await ref
          .read(secureStorageProvider)
          .write(key: 'nickname', value: updated);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _nickname = updated;
        _editing = false;
        _nicknameError = null;
        _nicknameDuplicate = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      // 409 Conflict → 닉네임 중복. 입력창 아래 안내 문구 2줄 노출(가입 화면과 동일).
      if (e.response?.statusCode == 409) {
        setState(() {
          _nicknameDuplicate = true;
          _nicknameError = null;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('닉네임을 변경하지 못했어요. 다시 시도해주세요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('닉네임을 변경하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _savingNickname = false);
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
    if (_withdrawing || _savingNickname || _loggingOut) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _palette.card,
        shape: const RoundedRectangleBorder(),
        title: Text('회원탈퇴', style: _palette.text(22, weight: 600)),
        content: Text(
          '탈퇴하면 모든 데이터가 삭제되며 복구할 수 없어요.\n정말로 탈퇴하시겠어요?',
          style: _palette.text(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('탈퇴', style: _palette.text(14, color: _palette.orange)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _withdrawing = true);
    try {
      final ds = MemberDataSource(ref.read(dioProvider));
      await ds.withdraw();
    } catch (_) {
      if (!mounted) return;
      setState(() => _withdrawing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원탈퇴를 완료하지 못했어요. 다시 시도해주세요.')),
      );
      return;
    }
    await _logout();
  }

  Future<void> _openUrl(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Keep a failed external launch recoverable on this screen.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('페이지를 열지 못했어요. 다시 시도해주세요.')));
  }

  bool get _busy => _savingNickname || _loggingOut || _withdrawing;

  @override
  Widget build(BuildContext context) => Theme(
    data: _palette.theme,
    child: Scaffold(
      backgroundColor: _palette.background,
      body: KeyboardDismisser(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 22, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '뒤로',
                      onPressed: _busy ? null : () => context.pop(),
                      icon: DesignIcon('chevron-left', color: _palette.ink),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MOABOOK / SETTINGS',
                      style: _palette.text(
                        10,
                        mono: true,
                        color: _palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '설정',
                        style: _palette.text(28, weight: 700, serif: true),
                      ),
                      const SizedBox(height: 17),
                      Divider(height: 1, thickness: 1.5, color: _palette.ink),
                      const SizedBox(height: 28),
                      Text(
                        '${_nickname.isEmpty ? "안녕하세요" : "$_nickname님, 안녕하세요"}!',
                        style: _palette.text(21, weight: 600, serif: true),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '나의 정보와 알림을 관리해요.',
                        style: _palette.text(13, color: _palette.muted),
                      ),
                      const SizedBox(height: 30),
                      _sectionLabel('닉네임'),
                      const SizedBox(height: 10),
                      if (_editing)
                        ..._buildEditingNickname()
                      else
                        _buildNicknameDisplay(),
                      const SizedBox(height: 28),
                      _buildPushToggle(),
                      const SizedBox(height: 30),
                      _sectionLabel('서비스 안내'),
                      const SizedBox(height: 8),
                      _menuItem('서비스 이용약관', () => _openUrl(_termsUrl)),
                      _menuItem('개인정보 처리방침', () => _openUrl(_privacyUrl)),
                      const SizedBox(height: 28),
                      _button(
                        _loggingOut ? '로그아웃 중…' : '로그아웃',
                        _busy ? null : _logout,
                        filled: true,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : _withdraw,
                          child: Text(
                            _withdrawing ? '탈퇴 처리 중…' : '회원탈퇴',
                            style: _palette.text(12, color: _palette.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _sectionLabel(String label) =>
      Text(label, style: _palette.text(12, weight: 600, color: _palette.muted));

  Widget _button(
    String label,
    VoidCallback? onPressed, {
    bool filled = false,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: filled ? _palette.ink : _palette.card,
        foregroundColor: filled ? _palette.card : _palette.ink,
        side: BorderSide(color: _palette.ink),
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size(0, 48),
        textStyle: _palette.text(14, weight: 600),
      ),
      child: Text(label),
    ),
  );

  Widget _menuItem(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _palette.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _palette.text(14))),
          DesignIcon('chevron-right', color: _palette.muted, size: 18),
        ],
      ),
    ),
  );

  Widget _buildPushToggle() {
    final asyncEnabled = ref.watch(pushSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('알림'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('푸시 알림 받기', style: _palette.text(14))),
            Switch.adaptive(
              value: asyncEnabled.valueOrNull ?? true,
              activeTrackColor: _palette.ink,
              onChanged: asyncEnabled.isLoading || _busy
                  ? null
                  : (value) =>
                        ref.read(pushSettingsProvider.notifier).toggle(value),
            ),
          ],
        ),
        Text(
          '책을 잊지 않도록 모아북이 가끔 알려드려요.',
          style: _palette.text(12, color: _palette.muted),
        ),
      ],
    );
  }

  Widget _buildNicknameDisplay() => InkWell(
    onTap: _busy
        ? null
        : () => setState(() {
            _editing = true;
            _nicknameCtrl.text = _nickname;
            _nicknameError = null;
            _nicknameDuplicate = false;
          }),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _palette.card,
        border: Border.all(color: _palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _nickname.isEmpty ? '닉네임 없음' : _nickname,
              style: _palette.text(14),
            ),
          ),
          Text('수정', style: _palette.text(12, weight: 600)),
          const SizedBox(width: 8),
          DesignIcon('pencil', color: _palette.ink, size: 16),
        ],
      ),
    ),
  );

  List<Widget> _buildEditingNickname() => [
    TextField(
      controller: _nicknameCtrl,
      autofocus: true,
      enabled: !_savingNickname,
      maxLength: 10,
      textInputAction: TextInputAction.done,
      onChanged: _validateNickname,
      onSubmitted: (_) => _saveNickname(),
      style: _palette.text(14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _palette.card,
        hintText: '닉네임을 입력해주세요',
        counterText: '',
        errorText: _nicknameDuplicate
            ? '중복된 닉네임이에요. 다시 확인해주세요.'
            : _nicknameError,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _button(
            '취소',
            _savingNickname
                ? null
                : () => setState(() {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _editing = false;
                    _nicknameCtrl.text = _nickname;
                    _nicknameError = null;
                    _nicknameDuplicate = false;
                  }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _button(
            _savingNickname ? '저장 중…' : '저장',
            _savingNickname || _nicknameError != null || _nicknameDuplicate
                ? null
                : _saveNickname,
            filled: true,
          ),
        ),
      ],
    ),
  ];
}
