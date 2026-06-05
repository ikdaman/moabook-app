import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/model/login_state.dart';
import '../../domain/model/logout_state.dart';
import '../../domain/model/signup_state.dart';
import '../../domain/repository/auth_repository.dart';
import '../datasource/auth_remote_datasource.dart';
import '../datasource/social_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SocialAuthDataSource _social;
  final FlutterSecureStorage _storage;

  const AuthRepositoryImpl(this._remote, this._social, this._storage);

  // ── Login ─────────────────────────────────────────────────────────────────

  @override
  Stream<LoginState> kakaoLogin() => _login(_social.kakaoLogin, _social.kakaoLogout);

  @override
  Stream<LoginState> naverLogin() => _login(_social.naverLogin, _social.naverLogout);

  @override
  Stream<LoginState> googleLogin() => _login(_social.googleLogin, _social.googleLogout);

  @override
  Stream<LoginState> appleLogin() => _login(_social.appleLogin, _social.appleLogout);

  Stream<LoginState> _login(
    Future<dynamic> Function() socialLoginFn,
    Future<void> Function() socialLogoutFn,
  ) async* {
    yield const LoginLoading();
    final social = await socialLoginFn();
    if (!social.isSuccess) {
      yield LoginError(social.errorMessage ?? '소셜 로그인에 실패했습니다.');
      return;
    }

    final token      = social.socialAccessToken!;
    final provider   = social.provider!;
    final providerId = social.providerId!;

    try {
      final (result, statusCode) = await _remote.login(
        socialToken: token,
        provider:    provider,
        providerId:  providerId,
      );

      if (result != null) {
        await _saveTokens(result.authorization, result.refreshToken,
            result.provider, result.nickname);
        yield const LoginSuccess();
      } else {
        yield const LoginError('로그인 실패');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        yield LoginSignupRequired(
          socialToken: token,
          provider:    provider,
          providerId:  providerId,
        );
      } else {
        yield LoginError('로그인 실패: ${e.message}');
      }
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  @override
  Stream<LogoutState> kakaoLogout() => _logout(_social.kakaoLogout);

  @override
  Stream<LogoutState> naverLogout() => _logout(_social.naverLogout);

  @override
  Stream<LogoutState> googleLogout() => _logout(_social.googleLogout);

  @override
  Stream<LogoutState> appleLogout() => _logout(_social.appleLogout);

  Stream<LogoutState> _logout(Future<void> Function() socialLogoutFn) async* {
    yield const LogoutLoading();
    try {
      try { await _remote.logout(); } catch (_) {}
      await socialLogoutFn();
      await _storage.deleteAll();
      yield const LogoutSuccess();
    } catch (e) {
      await _storage.deleteAll();
      yield LogoutError(e.toString());
    }
  }

  // ── Signup ────────────────────────────────────────────────────────────────

  @override
  Stream<SignupState> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  }) async* {
    yield const SignupLoading();
    try {
      final result = await _remote.signup(
        socialToken: socialToken,
        provider:    provider,
        providerId:  providerId,
        nickname:    nickname,
      );
      if (result != null) {
        await _saveTokens(result.authorization, result.refreshToken,
            result.provider, result.nickname);
        yield const SignupSuccess();
      } else {
        yield const SignupError('회원가입 실패');
      }
    } on DioException catch (e) {
      // 409 Conflict → 닉네임 중복. 화면에서 안내 문구 노출용 전용 상태.
      if (e.response?.statusCode == 409) {
        yield const SignupNicknameDuplicate();
      } else {
        yield SignupError('회원가입 실패: ${e.message}');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _saveTokens(
    String authorization,
    String refreshToken,
    String provider,
    String nickname,
  ) async {
    await Future.wait([
      _storage.write(key: 'access_token',  value: authorization),
      _storage.write(key: 'refresh_token', value: refreshToken),
      _storage.write(key: 'provider',      value: provider),
      _storage.write(key: 'nickname',      value: nickname),
    ]);
  }

  @override
  Future<String?> getProvider() => _storage.read(key: 'provider');

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }
}
