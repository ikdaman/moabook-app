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

  Future<void> _consumeLogin(Stream<LoginState> stream) async {
    await for (final state in stream) {
      // LoginSuccess 가 listener 로 전파되어 /main 으로 navigate 되기 직전에
      // isLoggedInProvider 캐시를 미리 채워둬야 홈/바텀바 첫 build 가
      // 로그인 상태로 그려진다. (invalidate 후 .future 를 await)
      if (state is LoginSuccess) {
        ref.invalidate(isLoggedInProvider);
        await ref.read(isLoggedInProvider.future);
      }
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> kakaoLogin()  => _consumeLogin(_repo.kakaoLogin());
  Future<void> naverLogin()  => _consumeLogin(_repo.naverLogin());
  Future<void> googleLogin() => _consumeLogin(_repo.googleLogin());
  Future<void> appleLogin()  => _consumeLogin(_repo.appleLogin());

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
      // 로그인 흐름과 동일하게 SignupSuccess 전파 전에 캐시 갱신.
      if (state is SignupSuccess) {
        ref.invalidate(isLoggedInProvider);
        await ref.read(isLoggedInProvider.future);
      }
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
