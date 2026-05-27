import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/datasource/auth_remote_datasource.dart';
import '../../../data/datasource/social_auth_datasource.dart';
import '../../../data/repository/auth_repository_impl.dart';
import '../../../domain/model/login_state.dart';
import '../../../domain/model/logout_state.dart';
import '../../../domain/model/signup_state.dart';
import '../../../domain/repository/auth_repository.dart';

// ── Infrastructure providers ─────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final dioProvider = Provider((ref) {
  final storage = ref.watch(secureStorageProvider);
  return createDioClient(storage);
});

// ── Repository providers ──────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio     = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(
    AuthRemoteDataSourceImpl(dio),
    SocialAuthDataSourceImpl(),
    storage,
  );
});

// ── State providers ───────────────────────────────────────────────────────

final loginStateProvider =
    StateProvider<LoginState>((ref) => const LoginInitial());

final signupStateProvider =
    StateProvider<SignupState>((ref) => const SignupSuccess());

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.isLoggedIn();
});

// ── Action notifier ───────────────────────────────────────────────────────

class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> kakaoLogin() async {
    await for (final state in _repo.kakaoLogin()) {
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> naverLogin() async {
    await for (final state in _repo.naverLogin()) {
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> googleLogin() async {
    await for (final state in _repo.googleLogin()) {
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> appleLogin() async {
    await for (final state in _repo.appleLogin()) {
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  }) async {
    await for (final state in _repo.signup(
      socialToken: socialToken,
      provider: provider,
      providerId: providerId,
      nickname: nickname,
    )) {
      ref.read(signupStateProvider.notifier).state = state;
    }
  }

  Future<void> logout() async {
    final provider = await _repo.getProvider();
    final stream = switch (provider?.toUpperCase()) {
      'KAKAO'  => _repo.kakaoLogout(),
      'NAVER'  => _repo.naverLogout(),
      'GOOGLE' => _repo.googleLogout(),
      'APPLE'  => _repo.appleLogout(),
      _        => _repo.kakaoLogout(),
    };
    await for (final state in stream) {
      if (state is LogoutError) break;
    }
    ref.invalidate(isLoggedInProvider);
    ref.read(loginStateProvider.notifier).state = const LoginInitial();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, void>(AuthNotifier.new);
